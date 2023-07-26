// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/libraries/CurrencyLibrary.sol";
import {IERC20Minimal} from "@uniswap/v4-core/contracts/interfaces/external/IERC20Minimal.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";

contract AtomicArb is Test {
    using PoolIdLibrary for IPoolManager.PoolKey;

    IPoolManager public immutable manager;
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    struct CallbackData {
        address sender;
        IPoolManager.PoolKey key0;
        IPoolManager.SwapParams params0;
        IPoolManager.PoolKey key1;
        bool takeToken0;
    }

    constructor(IPoolManager _poolManager) {
        manager = _poolManager;
    }

    function arb(
        IPoolManager.PoolKey calldata key0,
        IPoolManager.SwapParams calldata params0,
        IPoolManager.PoolKey calldata key1,
        bool takeToken0
    ) external returns (BalanceDelta delta) {
        delta = abi.decode(
            manager.lock(abi.encode(CallbackData(msg.sender, key0, params0, key1, takeToken0))), (BalanceDelta)
        );
    }

    function lockAcquired(uint256, bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        BalanceDelta delta0 = manager.swap(data.key0, data.params0);
        BalanceDelta delta1 = manager.swap(
            data.key1,
            IPoolManager.SwapParams({
                zeroForOne: !data.params0.zeroForOne,
                amountSpecified: !data.params0.zeroForOne ? -delta0.amount0() : -delta0.amount1(),
                sqrtPriceLimitX96: !data.params0.zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            })
        );
        BalanceDelta net = delta0 + delta1;
        settleTake(data.sender, data.key0.currency0, data.key0.currency1, !data.takeToken0, net);

        return abi.encode(net);
    }

    /// @notice Settle/Take currencies from Pool manager, using ERC20 transfers
    function settleTake(address sender, Currency currency0, Currency currency1, bool zeroForOne, BalanceDelta delta)
        internal
    {
        if (zeroForOne) {
            if (delta.amount0() > 0) {
                console.log("Sending %s token0 to manager", uint256(uint128(delta.amount0())));
                IERC20Minimal(Currency.unwrap(currency0)).transferFrom(
                    sender, address(manager), uint128(delta.amount0())
                );
                manager.settle(currency0);
            }
            if (delta.amount1() < 0) {
                console.log("Taking %s token1 from manager", uint256(uint128(-delta.amount1())));
                manager.take(currency1, sender, uint128(-delta.amount1()));
            }
        } else {
            if (delta.amount1() > 0) {
                console.log("Sending %s token1 to manager", uint256(uint128(delta.amount1())));
                IERC20Minimal(Currency.unwrap(currency1)).transferFrom(
                    sender, address(manager), uint128(delta.amount1())
                );
                manager.settle(currency1);
            }
            if (delta.amount0() < 0) {
                console.log("Taking %s token0 from manager", uint256(uint128(-delta.amount0())));
                manager.take(currency0, sender, uint128(-delta.amount0()));
            }
        }
    }
}

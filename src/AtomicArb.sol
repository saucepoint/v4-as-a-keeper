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

contract AtomicArb is Test {
    using PoolIdLibrary for IPoolManager.PoolKey;

    IPoolManager public immutable manager;

    struct CallbackData {
        address sender;
        IPoolManager.PoolKey key0;
        IPoolManager.SwapParams params0;
        IPoolManager.PoolKey key1;
        IPoolManager.SwapParams params1;
    }

    constructor(IPoolManager _poolManager) {
        manager = _poolManager;
    }

    function arb(
        IPoolManager.PoolKey calldata key0,
        IPoolManager.SwapParams calldata params0,
        IPoolManager.PoolKey calldata key1,
        IPoolManager.SwapParams calldata params1
    ) external {
        BalanceDelta delta =
            abi.decode(manager.lock(abi.encode(CallbackData(msg.sender, key0, params0, key1, params1))), (BalanceDelta));
    }

    function lockAcquired(uint256, bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        BalanceDelta delta0 = manager.swap(data.key0, data.params0);
        console2.log(delta0.amount0()); // 100, send 100 token0 to manager
        console2.log(delta0.amount1()); // -98, pull 98 token1 from manager
        BalanceDelta delta1 = manager.swap(data.key1, data.params1);
        console2.log(delta1.amount0()); // -140, pull 140 token0 from manager
        console2.log(delta1.amount1()); // 100, send 100 token1 to manager

        settleTake(data.sender, data.key0, data.params0, delta0);
        settleTake(data.sender, data.key1, data.params1, delta1);

        BalanceDelta net = delta0 + delta1;
        console2.log(net.amount0());
        console2.log(net.amount1());

        return abi.encode(net);
    }

    /// @notice Settle/Take currencies from Pool manager, using ERC20 transfers
    function settleTake(
        address sender,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams memory params,
        BalanceDelta delta
    ) internal {
        if (params.zeroForOne) {
            if (delta.amount0() > 0) {
                console.log("Sending %s token0 to manager", uint256(uint128(delta.amount0())));
                IERC20Minimal(Currency.unwrap(key.currency0)).transferFrom(
                    sender, address(manager), uint128(delta.amount0())
                );
                manager.settle(key.currency0);
            }
            if (delta.amount1() < 0) {
                console.log("Taking %s token1 from manager", uint256(uint128(-delta.amount1())));
                manager.take(key.currency1, sender, uint128(-delta.amount1()));
            }
        } else {
            if (delta.amount1() > 0) {
                console.log("Sending %s token1 to manager", uint256(uint128(delta.amount1())));
                IERC20Minimal(Currency.unwrap(key.currency1)).transferFrom(
                    sender, address(manager), uint128(delta.amount1())
                );
                manager.settle(key.currency1);
            }
            if (delta.amount0() < 0) {
                console.log("Taking %s token0 from manager", uint256(uint128(-delta.amount0())));
                manager.take(key.currency0, sender, uint128(-delta.amount0()));
            }
        }
    }

    function logBalances(IPoolManager.PoolKey memory key) public {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        console.log("t0 balance %s", IERC20Minimal(token0).balanceOf(address(this)));
        console.log("t1 balance %s", IERC20Minimal(token1).balanceOf(address(this)));
    }
}

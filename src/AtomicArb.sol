// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "v4-periphery/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/libraries/CurrencyLibrary.sol";
import {IERC20Minimal} from "@uniswap/v4-core/contracts/interfaces/external/IERC20Minimal.sol";

contract AtomicArb {
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
        BalanceDelta delta1 = manager.swap(data.key1, data.params1);
        settleTake(data.sender, data.key0, data.params0, delta0);
        settleTake(data.sender, data.key1, data.params1, delta1);

        // return abi.encode(delta) of the arb
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
                IERC20Minimal(Currency.unwrap(key.currency0)).transferFrom(
                    sender, address(manager), uint128(delta.amount0())
                );
                manager.settle(key.currency0);
            }
            if (delta.amount1() < 0) {
                manager.take(key.currency1, sender, uint128(-delta.amount1()));
            }
        } else {
            if (delta.amount1() > 0) {
                IERC20Minimal(Currency.unwrap(key.currency1)).transferFrom(
                    sender, address(manager), uint128(delta.amount1())
                );
                manager.settle(key.currency1);
            }
            if (delta.amount0() < 0) {
                manager.take(key.currency0, sender, uint128(-delta.amount0()));
            }
        }
    }
}

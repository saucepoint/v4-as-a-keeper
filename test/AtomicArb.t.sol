// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/foundry-tests/utils/Deployers.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/libraries/CurrencyLibrary.sol";
import {HookTest} from "./utils/HookTest.sol";
import {Counter} from "../src/Counter.sol";
import {CounterImplementation} from "./implementation/CounterImplementation.sol";
import {AtomicArb} from "../src/AtomicArb.sol";

contract AtomicArbTest is HookTest, Deployers, GasSnapshot {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using CurrencyLibrary for Currency;

    AtomicArb arb;
    Counter counter = Counter(address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)));
    IPoolManager.PoolKey key0;
    IPoolManager.PoolKey key1;

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        HookTest.initHookTestEnv();

        // testing environment requires our contract to override `validateHookAddress`
        // well do that via the Implementation contract to avoid deploying the override with the production contract
        CounterImplementation impl = new CounterImplementation(manager, counter);
        etchHook(address(impl), address(counter));

        // Create the pools
        // hookless pool
        key0 = IPoolManager.PoolKey(
            Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0x0))
        );
        manager.initialize(key0, SQRT_RATIO_1_1);

        // hooked pool
        key1 = IPoolManager.PoolKey(
            Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(counter)
        );
        manager.initialize(key1, SQRT_RATIO_1_1);

        // Provide liquidity to the pools
        modifyPositionRouter.modifyPosition(key0, IPoolManager.ModifyPositionParams(-60, 60, 10 ether));
        modifyPositionRouter.modifyPosition(key0, IPoolManager.ModifyPositionParams(-120, 120, 10 ether));
        modifyPositionRouter.modifyPosition(
            key0, IPoolManager.ModifyPositionParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether)
        );
        modifyPositionRouter.modifyPosition(key1, IPoolManager.ModifyPositionParams(-60, 60, 10 ether));
        modifyPositionRouter.modifyPosition(key1, IPoolManager.ModifyPositionParams(-120, 120, 10 ether));
        modifyPositionRouter.modifyPosition(
            key1, IPoolManager.ModifyPositionParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether)
        );

        arb = new AtomicArb(manager);
        token0.approve(address(arb), 2 ** 128);
        token1.approve(address(arb), 2 ** 128);
    }

    function test_simpleArb_take0() public {
        // On the main pool, create price discrepancy
        swap(key0, 2e18, true); // sell token0 for token1

        // arbitrage: buy token1 on key1 (cheap), sell token1 on key0
        // taking token0 from the pool as profit
        arb.arb(
            key1,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 102,
                sqrtPriceLimitX96: MIN_PRICE_LIMIT // unlimited impact
            }),
            key0,
            true
        );
    }

    function test_simpleArb_take1() public {
        // On the main pool, create price discrepancy
        swap(key0, 2e18, false); // sell token1 for token0

        // arbitrage: buy token1 on key1 (cheap), sell token1 on key0
        // taking token0 from the pool as profit
        arb.arb(
            key1,
            IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 102,
                sqrtPriceLimitX96: MAX_PRICE_LIMIT // unlimited impact
            }),
            key0,
            false
        );
    }
}

# v4-template

### **A template for writing Uniswap v4 Hooks 🦄**

[`Use this Template`](https://github.com/saucepoint/v4-template/generate)

1. The example hook [Counter.sol](src/Counter.sol) demonstrates the `beforeSwap()` and `afterSwap()` hooks
2. The test template [Counter.t.sol](test/Counter.t.sol) preconfigures the v4 pool manager, test tokens, and test liquidity.

<details>
<summary>Refetch v3 data</summary>

_requires cryo_

Fetch 14 days of liquidity provision + swaps from the Uni v3 ETH/USDC 5bps Pool

```bash
cryo logs \
    -o cryo_data/ \
    --blocks 17686540:17787340 \
    --contract 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 \
    --rpc <RPC_URL>
```

> Avoid using Free RPCs (LlamaNodes, Ankr). With rate limits, 14 days of logs will take 7 hours. Infura allows for 100k requests per day, which took 203 seconds

</details>

---

### Local Development (Anvil)

_requires [foundry](https://book.getfoundry.sh)_

```
forge install
forge test
```

Because v4 exceeds the bytecode limit of Ethereum and it's _business licensed_, we can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/).

```bash
# start anvil, with a larger code limit
anvil --code-size-limit 30000

# in a new terminal
forge script script/Anvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --code-size-limit 30000 \
    --broadcast
```

---

Additional resources:

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

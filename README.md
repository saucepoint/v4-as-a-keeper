# v4-as-a-keeper

### **Using Uniswap v4 Hooks 🦄 for keeper activity**

This repo is mostly a sandbox for measuring and testing "v4-as-a-keeper"

The idea is using arbitrage between the dominant pool and the obscure pool to pay for execution (keeper jobs)

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

_requires [foundry](https://book.getfoundry.sh)_

```
forge install
forge test
```

---

Additional resources:

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

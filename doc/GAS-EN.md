# Gas optimization — Account Abstraction (ERC-4337)

[🇪🇸 Español](./GAS-ES.md) · 🇬🇧 English

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract UserOpGasTest --gas-report
forge snapshot --match-contract UserOpGasTest
```

**Baseline date:** 2026-09-10 (Phase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/UserOp.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## EOA vs UserOp comparison (same effect: `MockTarget.setValue`)

Measurement = gas of the **full Foundry test** (includes signature/`handleOps` setup where applicable). Useful for orders of magnitude, not as the exact on-chain cost of the inner call alone.

| Path | Gas (snapshot) | vs EOA |
|------|----------------|--------|
| `testGas_EOA_setValue` | **54 582** | baseline |
| `testGas_UserOp_setValue` (no paymaster) | **159 870** | **+105 288** (~2.9×) |
| `testGas_UserOp_withPaymaster_setValue` | **199 504** | **+144 922** (~3.7×) |

### Isolated components (EntryPoint prank)

| Path | Gas | Notes |
|------|-----|-------|
| `testGas_execute_only` | ~61 018 | `SmartAccount.execute` only |
| `testGas_validateUserOp_only` | ~36 060 | ECDSA + EP auth |
| `testGas_validatePaymasterUserOp_only` | ~40 005 | Whitelist + deposit + timestamps |

> The AA overhead comes mostly from `EntryPoint.handleOps` (validation, prefund, events, settlement), not from `setValue` itself.

---

## Where the gas goes (qualitatively)

| Stage | No paymaster | With paymaster |
|-------|--------------|----------------|
| ECDSA `validateUserOp` | Yes | Yes |
| Prefund / account deposit | Yes | Usually 0 (PM pays) |
| `validatePaymasterUserOp` + `postOp` | No | Yes |
| `callData` execution | Yes | Yes |
| EntryPoint overhead / events | Yes | Yes (+ more) |

---

## Optimizations already applied in the module

| Technique | Where | Effect |
|-----------|-------|--------|
| **immutable** `entryPoint` / `owner` | `SmartAccount` | No SLOAD on the auth/signature hot path |
| **immutable** `entryPoint` | `SponsoringPaymaster` | Same |
| OZ ECDSA `tryRecover` | `SignatureValidator` | No revert on soft-fail; anti-malleability `s` |
| Signature soft-fail → `validationData` | Account | Avoids an expensive revert on failed signature simulation |
| Pack gas fees / limits into `bytes32` | UserOp v0.7 | Less calldata vs unpacked v0.6 |
| `calldata` in execute / validate | Account / PM | Fewer memory copies |
| Custom errors | Module | Cheaper than `require` strings |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Aggressive inlining |

---

## Accepted trade-offs

| Decision | Why |
|----------|-----|
| Immutable owner (no on-chain rotation) | v1 simplicity; rotate = redeploy / factory (future) |
| `_payPrefund` with `gas: type(uint256).max` | AA spec / BaseAccount; the EP verifies the deposit |
| `block.timestamp` in the paymaster | Module business rule + `validationData` to the EP |
| `totalSponsoredGasCost` accounting in `postOp` | Observability > SSTORE micro-savings |

---

## Deploy

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

See `script/Deploy.s.sol` for env (`ENTRY_POINT`, deposits, owner).

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md)

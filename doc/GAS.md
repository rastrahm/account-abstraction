# Optimización de gas — Account Abstraction (ERC-4337)

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract UserOpGasTest --gas-report
forge snapshot --match-contract UserOpGasTest
```

**Fecha baseline:** 2026-09-10 (Fase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/UserOp.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Comparativa EOA vs UserOp (mismo efecto: `MockTarget.setValue`)

Medición = gas del **test Foundry completo** (incluye setup de firma/`handleOps` donde aplica). Sirve para órdenes de magnitud, no como coste on-chain exacto de solo la call interna.

| Path | Gas (snapshot) | vs EOA |
|------|----------------|--------|
| `testGas_EOA_setValue` | **54 582** | baseline |
| `testGas_UserOp_setValue` (sin paymaster) | **159 870** | **+105 288** (~2.9×) |
| `testGas_UserOp_withPaymaster_setValue` | **199 504** | **+144 922** (~3.7×) |

### Componentes aislados (prank EntryPoint)

| Path | Gas | Notas |
|------|-----|--------|
| `testGas_execute_only` | ~61 018 | Solo `SmartAccount.execute` |
| `testGas_validateUserOp_only` | ~36 060 | ECDSA + auth EP |
| `testGas_validatePaymasterUserOp_only` | ~40 005 | Whitelist + depósito + timestamps |

> El overhead AA viene sobre todo de `EntryPoint.handleOps` (validación, prefund, eventos, liquidación), no de `setValue` en sí.

---

## Dónde se va el gas ( qualitatively )

| Etapa | Sin paymaster | Con paymaster |
|-------|---------------|---------------|
| ECDSA `validateUserOp` | Sí | Sí |
| Prefund / depósito cuenta | Sí | Suele 0 (PM paga) |
| `validatePaymasterUserOp` + `postOp` | No | Sí |
| Ejecución `callData` | Sí | Sí |
| Overhead EntryPoint / eventos | Sí | Sí (+ más) |

---

## Optimizaciones ya aplicadas en el módulo

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `entryPoint` / `owner` **immutable** | `SmartAccount` | Sin SLOAD en hot path de auth/firma |
| `entryPoint` **immutable** | `SponsoringPaymaster` | Idem |
| ECDSA OZ `tryRecover` | `SignatureValidator` | Sin revert en soft-fail; anti-malleability `s` |
| Soft-fail firma → `validationData` | Account | Evita revert caro en simulación fallida de firma |
| Pack gas fees / limits en `bytes32` | UserOp v0.7 | Menos calldata vs v0.6 unpacked |
| `calldata` en execute / validate | Account / PM | Menos copias memory |
| Custom errors | Módulo | Más barato que `require` strings |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining agresivo |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Owner immutable (sin rotación on-chain) | Simplicidad v1; rotar = redeploy / factory (futuro) |
| `_payPrefund` con `gas: type(uint256).max` | Spec AA / BaseAccount; EP verifica depósito |
| `block.timestamp` en paymaster | Regla de negocio del módulo + `validationData` a EP |
| Contabilidad `totalSponsoredGasCost` en `postOp` | Observabilidad > micro-ahorro de SSTORE |

---

## Deploy

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Ver `script/Deploy.s.sol` para env (`ENTRY_POINT`, depósitos, owner).

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md)

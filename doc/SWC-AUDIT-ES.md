# Auditoría SWC — Account Abstraction (ERC-4337)

🇪🇸 Español · [🇬🇧 English](./SWC-AUDIT-EN.md)

Verificación de Smart Account, Signature Validator y Sponsoring Paymaster contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, EntryPoint-only auth, ECDSA).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/) y la [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) security considerations.

**Contratos auditados (prod / core):**  
`src/account/SmartAccount.sol`, `src/paymaster/SponsoringPaymaster.sol`,  
`src/validation/SignatureValidator.sol`,  
`src/libraries/UserOperationLib.sol`, `src/libraries/ValidationDataLib.sol`,  
`src/interfaces/*`, `src/errors/AccountAbstractionErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
`lib/account-abstraction` EntryPoint v0.7, OpenZeppelin ECDSA / Ownable2Step

**Mocks (fuera de prod):** `src/mocks/*`  
**Fecha:** 2026-09-10  
**Referencia tests:** `test/SmartAccount.t.sol`, `test/SponsoringPaymaster.t.sol`, `test/SignatureValidator.t.sol`,  
`test/UserOpE2E.t.sol`, `test/UnauthorizedSender.t.sol`, `test/fuzz/`, `test/gas/`  
**Estilo:** alineado a [`11-upgradeable-proxies/doc/SWC-AUDIT-ES.md`](../../11-upgradeable-proxies/doc/SWC-AUDIT-ES.md)  
**Índice docs:** [`README-ES.md`](./README-ES.md) · README módulo: [`../README-ES.md`](../README-ES.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 30 |
| ⚠️ Informativo (diseño / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (Account + Paymaster + SignatureValidator sobre EntryPoint v0.7). El módulo **restringe validación/ejecución a `msg.sender == entryPoint`**, verifica ECDSA con OZ (anti-malleability), y el paymaster exige whitelist + depósito + ventana temporal. Riesgos informativos: owner/paymaster-owner centralizados, uso de `block.timestamp` en validación del paymaster (además de `validationData`), y dependencia de un EntryPoint canónico correcto en deploy.

**Principios del suite / módulo 12 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `AccountAbstractionErrors` |
| Pragma fijo `0.8.24` | ✅ |
| `msg.sender == entryPoint` en validate/execute/postOp | ✅ + unauthorized suite |
| ECDSA sobre `userOpHash` + eth-signed prefix | ✅ OZ `tryRecover` |
| Nonce 2D vía EntryPoint | ✅ e2e AA25 |
| Paymaster depósito / reglas / timestamps | ✅ unit + e2e |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Attack suite unauthorized | ✅ `test/UnauthorizedSender.t.sol` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Account Abstraction |
|----|--------|--------|--------|----------------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `totalSponsoredGasCost +=` checked |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `execute` / batch checan `success` → `ExecutionFailed`; `_payPrefund` ignora fallo a propósito (spec AA) |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | Sin withdraw libre; `withdrawDepositTo` / `withdrawTo` solo EP o `onlyOwner` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Parcial | ✅ | `execute` solo callable por EntryPoint (no reentrada anónima); EP usa `ReentrancyGuard`; CEI en paymaster admin |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `private` / `immutable` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` en contratos del módulo |
| SWC-113 | DoS with Failed Call | Sí | ✅ | Call fallido → `ExecutionFailed`; EP puede liquidar gas igualmente (e2e) |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Bundler / mempool ordering de UserOps; ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por `msg.sender` (== EntryPoint / owner OZ) |
| SWC-116 | Block values as a proxy for time | Sí | ⚠️ | Paymaster lee `block.timestamp` + empaqueta `validUntil`/`validAfter` |
| SWC-117 | Signature Malleability | Sí | ✅ | OZ ECDSA rechaza `s` alto / length inválida |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado en core |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | Sí | ✅ | `userOpHash` incluye EP+chainId; nonce 2D EntryPoint (AA25 e2e) |
| SWC-122 | Lack of Proper Signature Verification | Sí | ✅ | Recover + compare `owner`; soft-fail `SIG_VALIDATION_FAILED` |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit/e2e/fuzz/unauthorized |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage arbitrario en core |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IPaymaster` + `Ownable2Step`; Account implementa `IAccount` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | UserOp con gas limits bajos puede fallar validación; acotado por bundler / firmantes |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | `executeBatch` largo puede OOG (ops / bundler) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en core |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | ETH en cuenta solo sale vía `execute` (EP); depósitos en EP separados |
| SWC-133 | Hash Collisions (var-length args) | Parcial | ✅ | Hash UserOp canónico AA (`encode` con `keccak256` de bytes dinámicos) |
| SWC-134 | Message call with hardcoded gas | Parcial | ⚠️ | `_payPrefund` usa `gas: type(uint256).max` (patrón BaseAccount AA) |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Storage / eventos públicos por diseño |

---

## Riesgos informativos

### SWC-116 — `block.timestamp` en paymaster

ERC-4337 recomienda **no** depender de `block.timestamp` dentro de `validate*` y en su lugar devolver `validUntil`/`validAfter` en `validationData` para que el EntryPoint lo aplique. Este módulo:

1. Empaqueta la ventana en `validationData` (EntryPoint la enforce).
2. **Además** revierte con `PaymasterValidationFailed` si el tiempo actual está fuera (regla de negocio de la planificación).

Riesgo: divergencia simulación bundler vs inclusión si el reloj cruza el borde entre simulación y minado. Mitigación operativa: márgenes en `validUntil` / `validAfter`.

### SWC-114 — Orden / bundling

Los UserOps compiten en mempools de bundlers. Front-running de intención de negocio es riesgo de dominio AA, no un bypass de firma. Mitigación: private relays / políticas de bundler (fuera de v1).

### SWC-134 — `gas: type(uint256).max` en prefund

Alineado a eth-infinitism `BaseAccount._payPrefund`. El EntryPoint es quien verifica que el depósito quedó cubierto; un fallo del `call` se ignora a propósito.

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `SmartAccount.owner` immutable | Pérdida de clave = cuenta inusable | Documentar; recovery/factory (futuro) |
| `SponsoringPaymaster.owner` | Whitelist / withdraw unilateral | `Ownable2Step` |
| EntryPoint incorrecto en constructor | Auth permanentemente mal apuntada | Deploy script + verificación de dirección canónica |
| Whitelist paymaster | Sponsorship a cuenta maliciosa si owner erró | Ops / multisig owner |

### SWC-126 / SWC-128 — gas limits y batches

`verificationGasLimit` / `callGasLimit` insuficientes → FailedOp. Batches enormes → OOG. Responsabilidad del builder de la UserOp / bundler.

---

## Checklist principios monorepo (+ módulo 12)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, … |
| EntryPoint-only validate/execute | ✅ | Unauthorized suite |
| ECDSA `userOpHash` | ✅ | + eth-signed message |
| Nonce vía EP 2D | ✅ | |
| Paymaster depósito + reglas | ✅ | |
| NatSpec públicas/externas | ✅ | Core + libs |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/UserOp.fuzz.t.sol` |
| Attack suite | ✅ | `test/UnauthorizedSender.t.sol` |
| Sin floating pragma | ✅ | `0.8.24` |
| Sin ETH `transfer`/`send` | ✅ | Solo `.call{value}` |
| Gas profiling UserOp vs EOA | ✅ | `doc/GAS-ES.md` |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **SmartAccount:** `immutable` EP/owner; `validateUserOp` / `execute` / `executeBatch` / `withdrawDepositTo` → `OnlyEntryPoint`; firma soft-fail; `ExecutionFailed` / `InvalidBatchLength`.
2. **SignatureValidator:** OZ `tryRecover` + `MessageHashUtils`; malleability rechazada; `InvalidUserOpSignature`.
3. **SponsoringPaymaster:** whitelist, `maxCostPerOp`, depósito EP, ventana temporal, header `paymasterAndData`; admin `Ownable2Step`; validate/postOp solo EP.
4. **UserOperationLib:** `getUserOpHash` ≡ `EntryPoint.getUserOpHash` (fuzz 1000).
5. **E2E:** handleOps con/sin PM, AA24/AA25, cobro de depósitos.

### Hardening Fase 6

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | `withdrawDepositTo` (solo EP) | SWC-105 — retiro de depósito sin path no autenticado |
| 2 | `script/Deploy.s.sol` | Deploy reproducible + funding |
| 3 | `test/gas/UserOp.gas.t.sol` + `.gas-snapshot` | Overhead vs EOA |
| 4 | `doc/SWC-AUDIT-ES.md` / `doc/GAS-ES.md` | Matriz SWC-100–136 + benchmarks |

### Observaciones no bloqueantes (v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | Owner de cuenta no rotatorio | Info | Account factory + guardians |
| 2 | Paymaster sin firma off-chain de sponsorship | Info | Estilo VerifyingPaymaster (opcional) |
| 3 | Timelock / multisig en owner del PM | Info | Gobernanza |
| 4 | Invariantes Foundry formales | Mejora | Handler handleOps |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | fuzz + `totalSponsoredGasCost` paths |
| SWC-103 | `forge build` pragma fijo |
| SWC-104 | `SmartAccount` `ExecutionFailed` |
| SWC-105 | `UnauthorizedSender` withdraw + PM `onlyOwner` |
| SWC-107 | Unauthorized + e2e (solo EP ejecuta) |
| SWC-116 | `SponsoringPaymaster` expired/tooEarly |
| SWC-117 / 122 | `SignatureValidator.t.sol` |
| SWC-121 | `UserOpE2E` replay AA25 |
| SWC-123 | unit + e2e + fuzz + unauthorized |
| Auth | `test/UnauthorizedSender.t.sol` |
| Hash | `UserOperationLib.t.sol` vs EntryPoint |

---

## Resultado de ejecución

```text
forge test --summary
# 2026-09-10 Fase 6
UserOperationLibTest          10 PASS (+ fuzz 1000)
ValidationDataLibTest          4 PASS (+ fuzz 1000)
SignatureValidatorTest        18 PASS (+ fuzz 1000)
SmartAccountTest              19 PASS
SponsoringPaymasterTest       19 PASS (+ fuzz 1000)
UserOpE2ETest                  9 PASS
UnauthorizedSenderTest         8 PASS
UserOpFuzzTest                 5 PASS (1000 runs c/u)
UserOpGasTest                  6 PASS
Total: 98 PASS / 0 FAIL / 0 SKIP
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337)
- [eth-infinitism/account-abstraction v0.7](https://github.com/eth-infinitism/account-abstraction)
- Módulo 11: [`11-upgradeable-proxies/doc/SWC-AUDIT-ES.md`](../../11-upgradeable-proxies/doc/SWC-AUDIT-ES.md)
- Gas: [`GAS-ES.md`](./GAS-ES.md)
- Plan: [`planificacion-ES.md`](./planificacion-ES.md)

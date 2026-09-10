# Planificación — Módulo 12: Account Abstraction (ERC-4337)

**Estado:** Fases **0–6** ✅ completadas. Módulo cerrado a nivel de planificación v1.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar.

---

## 1. Objetivo

Construir un stack ERC-4337 de nivel producción con:

- **Smart Contract Account** compliant con `IAccount` (`validateUserOp` + ejecución).
- **Paymaster** custom (`IPaymaster`) para patrocinio de gas con reglas de expiración/sponsorship.
- **Signature Validator** ECDSA sobre secp256k1 vía `userOpHash`.
- Integración estricta con **EntryPoint** (`msg.sender == entryPoint`).
- Stack: **Foundry + Solidity `0.8.24`** (pragma fijo), calldata unpacking a bajo nivel donde aporte gas/claridad.

---

## 2. Alcance

| Incluido | Excluido (v1) |
|----------|----------------|
| Account, Paymaster, Signature Validator, interfaces ERC-4337, tests e2e/fuzz/gas | Aggregator de firmas / session keys complejas |
| Validación `userOpHash` + ECDSA | Passkeys / WebAuthn / recovery social |
| Depósito Paymaster en EntryPoint + reglas de sponsorship | Bundler off-chain de producción |
| Nonce 2D vía EntryPoint (`getNonce(address,uint192)`) | Frontend (fase opcional posterior) |
| Custom errors del módulo | Account factory multi-clone avanzada (opcional post-v1) |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite`)

- Solidity **exacto** `0.8.24`.
- OpenZeppelin Contracts v5.x para ECDSA / utilidades auditadas donde aporte valor.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports.
- Custom errors (no `require` con strings).
- CEI / access control en funciones administrativas.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 12 (ERC-4337)

- Spec fijada: **ERC-4337 v0.7** (`PackedUserOperation`, eth-infinitism `account-abstraction@v0.7.0`).
- Interfaces módulo: `IAccount`, `IPaymaster`, `IEntryPoint` (aliases tipados sobre AA).
- Autorización: `msg.sender == address(entryPoint)` en `validateUserOp`, `execute`/`executeBatch`, `withdrawDepositTo`, `validatePaymasterUserOp` y `postOp`.
- Firma: ECDSA secp256k1 sobre `userOpHash` + prefijo eth-signed; soft-fail → `SIG_VALIDATION_FAILED`.
- Paymaster: depósito EP + whitelist + `maxCostPerOp` + `validUntil`/`validAfter`; fallo → `PaymasterValidationFailed`.
- Nonces: EntryPoint 2D (`getNonce(address,uint192)`).
- Ejecución fallida → `ExecutionFailed`; caller no-EntryPoint → `OnlyEntryPoint`.

---

## 4. Arquitectura (final v1)

```
12-account-abstraction/
├── README.md
├── doc/
│   ├── README.md                     # índice de documentación
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md
│   └── GAS.md
├── src/
│   ├── account/SmartAccount.sol
│   ├── paymaster/SponsoringPaymaster.sol
│   ├── validation/SignatureValidator.sol
│   ├── libraries/
│   │   ├── UserOperationLib.sol
│   │   └── ValidationDataLib.sol
│   ├── interfaces/
│   │   ├── IAccount.sol
│   │   ├── IPaymaster.sol
│   │   ├── IEntryPoint.sol
│   │   └── UserOperation.sol
│   ├── errors/AccountAbstractionErrors.sol
│   └── mocks/MockTarget.sol
├── test/
│   ├── helpers/UserOpTestBase.sol
│   ├── UserOperationLib.t.sol
│   ├── ValidationDataLib.t.sol
│   ├── SignatureValidator.t.sol
│   ├── SmartAccount.t.sol
│   ├── SponsoringPaymaster.t.sol
│   ├── UserOpE2E.t.sol
│   ├── UnauthorizedSender.t.sol
│   ├── fuzz/UserOp.fuzz.t.sol
│   └── gas/UserOp.gas.t.sol
├── script/Deploy.s.sol
├── foundry.toml
├── remappings.txt
└── .gas-snapshot
```

### Contratos y responsabilidades

| Contrato / artefacto | Responsabilidad |
|----------------------|-----------------|
| `SmartAccount` | Valida UserOp (firma); ejecuta calls; depósitos EP; solo EntryPoint |
| `SignatureValidator` | ECDSA recover / validate / `toValidationData` |
| `SponsoringPaymaster` | Whitelist + depósito + ventana temporal; `postOp` contable |
| `UserOperationLib` | Pack gas/paymaster; `getUserOpHash` ≡ EntryPoint |
| `ValidationDataLib` | Pack/parse `validationData` (Helpers AA) |
| `EntryPoint` (dep) | `handleOps`, nonces 2D, cobro de gas |
---

## 5. Errores custom (obligatorios del módulo)

```solidity
error OnlyEntryPoint();
error ExecutionFailed();
error InvalidUserOpSignature();
error PaymasterValidationFailed();
error ZeroAddress();
error InvalidBatchLength();
```

Ampliar solo si hace falta, siempre como custom errors.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta que digas explícitamente: *“autorizo Fase N”* (o equivalente). |
| **Entrega** | Al cerrar una fase: checklist de aceptación + resumen de archivos tocados. |
| **Bloqueo** | Si aparece alcance nuevo, se documenta y se espera nueva autorización. |
| **TDD** | Dentro de cada fase de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + deps ERC-4337 | ✅ Completada | ✅ Autorizada |
| 1 | Interfaces + `UserOperation` + libs de hash | ✅ Completada | ✅ Autorizada |
| 2 | `SignatureValidator` + owner ECDSA | ✅ Completada | ✅ Autorizada |
| 3 | `SmartAccount` (`validateUserOp` + execute) | ✅ Completada | ✅ Autorizada |
| 4 | `SponsoringPaymaster` (validate + postOp + depósito) | ✅ Completada | ✅ Autorizada |
| 5 | Suite e2e + unauthorized sender + fuzz | ✅ Completada | ✅ Autorizada |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ✅ Completada | ✅ Autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable con tooling y dependencias ERC-4337 fijadas.

1. `forge init` (o estructura mínima compatible con la suite).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000.
3. Dependencias: `forge-std`, OpenZeppelin v5, y EntryPoint / account-abstraction (versión v0.6 o v0.7 documentada).
4. Carpetas `src/{account,paymaster,validation,interfaces,libraries}`, `test/`, `test/fuzz`, `test/gas`, `script/`, `doc/`.

**Criterio de salida:** `forge build` OK; versión ERC-4337 elegida escrita en esta sección.

**Hecho (2026-09-09):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer, fuzz `runs = 1000`) + `remappings.txt`.
- Dependencias en `lib/` (gitignored): `forge-std`, OpenZeppelin **v5.2.0**, `eth-infinitism/account-abstraction` **v0.7.0** (`PackedUserOperation`, `EntryPoint`, `IAccount`, `IPaymaster`).
- Spec fijada: **ERC-4337 v0.7** (no v0.6).
- Carpetas `src/{account,paymaster,validation,interfaces,libraries,errors}`, `test/{fuzz,gas}`, `script/`.
- Stub `src/Placeholder.sol` + smoke `test/Placeholder.t.sol`.
- Remappings verificados (`account-abstraction/interfaces/...`).
- `forge build` y `forge test` en verde (**1 PASS**).

---

### Fase 1 — Interfaces + UserOperation + hash ✅

**Objetivo:** tipos e interfaces estables para el resto del módulo.

1. Definir / adaptar `UserOperation` (o `PackedUserOperation` si v0.7).
2. Interfaces `IAccount`, `IPaymaster`, `IEntryPoint` alineadas a la spec elegida.
3. Library de hash de UserOp (compatible con EntryPoint).
4. Tests unitarios del hash / packing si hay lógica propia.

**Criterio de salida:** compilación limpia; hash de UserOp verificable contra referencia EntryPoint.

**Hecho (2026-09-09):**
- Interfaces módulo: `IAccount`, `IPaymaster`, `IEntryPoint` (heredan eth-infinitism v0.7).
- Docs `UserOperation.sol` + `UserOperationDocs.SPEC` = `ERC-4337-v0.7-PackedUserOperation`.
- `UserOperationLib`: pack gas/paymaster, `encode`/`hash`/`getUserOpHash` ≡ `EntryPoint.getUserOpHash`.
- `ValidationDataLib`: pack/parse ≡ `Helpers.sol` AA.
- `AccountAbstractionErrors` (custom errors del módulo).
- Tests: `UserOperationLib.t.sol` + `ValidationDataLib.t.sol` (incluye fuzz 1000 vs EntryPoint real).
- Stub `Placeholder` eliminado.
- **14 PASS** (`forge test`).

---

### Fase 2 — SignatureValidator ✅

**Objetivo:** verificación ECDSA eficiente sobre `userOpHash`.

1. Tests: firma válida → OK; firma inválida / signer incorrecto → `InvalidUserOpSignature`.
2. Implementar recover + comparación con `owner`.
3. NatSpec + custom errors.

**Criterio de salida:** suite de firma en verde (válida / inválida / malformed).

**Hecho (2026-09-09):**
- `src/validation/SignatureValidator.sol` (library): `recoverSigner`, `isValidSignature`, `validateSignature`, `toValidationData`.
- ECDSA OZ v5 + `MessageHashUtils.toEthSignedMessageHash` (personal_sign, alineado a SimpleAccount AA).
- Reverts: `InvalidUserOpSignature`, `ZeroAddress` (owner = 0).
- Soft-fail ERC-4337 vía `toValidationData` → `SIG_VALIDATION_SUCCESS` / `FAILED`.
- Tests: válida, wrong signer, wrong hash, malformed, empty, raw hash sin prefijo ETH, e2e con `EntryPoint.getUserOpHash`, fuzz.
- **32 PASS** total (`forge test`).

---

### Fase 3 — SmartAccount ✅

**Objetivo:** cuenta ERC-4337 con validación y ejecución solo vía EntryPoint.

1. Tests primero: `validateUserOp` desde no-EP → `OnlyEntryPoint`.
2. `validateUserOp`: firma + (si aplica) missingAccountFunds / depósito.
3. `execute` / `executeBatch`: solo EntryPoint; fallo de call → `ExecutionFailed`.
4. Owner / inicialización segura; `immutable` EntryPoint.

**Criterio de salida:** validación + ejecución feliz; unauthorized sender cubierto.

**Hecho (2026-09-09):**
- `src/account/SmartAccount.sol`: `entryPoint` + `owner` immutable; `validateUserOp`, `execute`, `executeBatch`, depósito/nonce helpers.
- Auth estricta: solo EntryPoint (ni siquiera el owner en directo) → `OnlyEntryPoint`.
- Firma vía `SignatureValidator.toValidationData` (soft-fail `SIG_VALIDATION_FAILED`).
- Prefund: `_payPrefund(missingAccountFunds)`; ejecución fallida → `ExecutionFailed`; batch inválido → `InvalidBatchLength`.
- Tests: unauthorized (stranger + owner), firma OK/fail, prefund, execute/batch, mock target.
- **51 PASS** total (`forge test`).

---

### Fase 4 — SponsoringPaymaster ✅

**Objetivo:** patrocinio de gas con reglas explícitas.

1. Tests: depósito insuficiente / expirado / regla fallida → `PaymasterValidationFailed`.
2. `validatePaymasterUserOp`: chequear depósito en EntryPoint + `validUntil` / whitelist / límites.
3. `postOp`: contabilidad post-ejecución (según modo).
4. Funciones admin (deposit/withdraw/stake) con access control.

**Criterio de salida:** UserOp patrocinada OK; caminos de rechazo en verde.

**Hecho (2026-09-10):**
- `src/paymaster/SponsoringPaymaster.sol`: whitelist, `maxCostPerOp`, ventana `validUntil`/`validAfter` en `paymasterAndData`, depósito EP, `postOp` + `totalSponsoredGasCost`.
- Auth: validate/postOp solo EntryPoint → `OnlyEntryPoint`; admin con `Ownable2Step`.
- Rechazos unificados → `PaymasterValidationFailed` (no whitelist, depósito, tope, tiempo, layout).
- Admin: `deposit`, `withdrawTo`, `addStake`, `unlockStake`, `withdrawStake`.
- Tests unitarios + fuzz de `maxCostPerOp` / depósito.
- **70 PASS** total (`forge test`).

---

### Fase 5 — Suite e2e + unauthorized + fuzz ✅

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | Struct UserOp → firma → EntryPoint → ejecución → deducción Paymaster |
| Unauthorized | `validateUserOp` / execute desde != EntryPoint → `OnlyEntryPoint` |
| Fuzz | targets, calldata, bounds de depósito Paymaster |

**Criterio de salida:** `forge test` verde; fuzz ≥ 1000 runs sin fallos inesperados.

**Hecho (2026-09-10):**
- `test/helpers/UserOpTestBase.sol` — build/sign/`handleOps` compartido.
- `test/UserOpE2E.t.sol` — sin/con paymaster, AA24/AA25, ejecución revertida, whitelist/depósito PM, value, nonce.
- `test/UnauthorizedSender.t.sol` — Account + Paymaster solo EntryPoint.
- `test/fuzz/UserOp.fuzz.t.sol` — setValue/transfer/paymaster/depósito/targets (1000 runs c/u).
- **91 PASS** total (`forge test`).

---

### Fase 6 — Gas + Deploy + hardening ✅

1. `script/Deploy.s.sol` (Account + Paymaster + funding EP).
2. `test/gas/UserOp.gas.t.sol`: overhead UserOp vs tx ECDSA EOA (órdenes de magnitud / deltas).
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md` al estilo de módulos previos.

**Criterio de salida:** deploy local reproducible + docs de seguridad + gas documentado.

**Hecho (2026-09-10):**
- `script/Deploy.s.sol` — EntryPoint (o `ENTRY_POINT` env), SmartAccount, SponsoringPaymaster, whitelist + depósitos.
- `test/gas/UserOp.gas.t.sol` + `.gas-snapshot` — EOA ~55k vs UserOp ~160k vs UserOp+PM ~200k.
- Hardening: `SmartAccount.withdrawDepositTo` (solo EntryPoint) — SWC-105.
- `doc/GAS.md` + `doc/SWC-AUDIT.md` (matriz SWC-100–136, estilo módulo 11): **0 vulnerabilidades**; 6 informativos.
- **98 PASS** total (`forge test`).

---

## 8. Matriz de pruebas (objetivo global)

| Caso | Qué valida |
|------|------------|
| E2E UserOp | Ciclo completo con/sin Paymaster |
| Unauthorized sender | `OnlyEntryPoint` |
| Firma inválida | `InvalidUserOpSignature` |
| Ejecución fallida | `ExecutionFailed` |
| Paymaster rechaza | `PaymasterValidationFailed` |
| Nonce EP | Reuso / avance correcto vía EntryPoint |
| Fuzz calldata / depósitos | Sin estados corruptos ni sponsorship indebido |
| Gas profiling | Delta documentado UserOp vs EOA |

---

## 9. Seguridad (checklist vivo)

- [x] `msg.sender == entryPoint` en validación y ejecución.
- [x] ECDSA sobre `userOpHash` canónico (sin malleability trivial mal manejada).
- [x] Paymaster verifica depósito / stake según spec y reglas de negocio.
- [x] Timestamps / `validUntil`–`validAfter` respetados.
- [x] Custom errors del módulo.
- [x] Sin floating pragma; NatSpec en APIs públicas.
- [x] Suite unauthorized + fuzz.
- [x] Gas profiling + (Fase 6) SWC-AUDIT.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido |
|---------|-----------|
| `README.md` | Índice de esta carpeta |
| `planificacion.md` | Este documento (fases + gates) |
| `diagrama-de-clases.md` | Estructura y relaciones entre contratos |
| `diagrama-de-flujo.md` | Flujos de decisión (validación, paymaster, ejecución) |
| `flujograma.md` | Flujos actor–sistema extremo a extremo |
| `SWC-AUDIT.md` | Matriz SWC-100–136 |
| `GAS.md` | Optimizaciones y benchmarks |

README raíz del módulo: `../README.md`.

---

## 11. Criterios de aceptación del módulo

1. [x] Compila con `pragma solidity 0.8.24`.
2. [x] Account + Paymaster operativos vía EntryPoint con tests e2e.
3. [x] Caller != EntryPoint no puede validar ni ejecutar.
4. [x] Firma inválida y paymaster inválido revierten / fallan con custom errors (o `SIG_VALIDATION_FAILED` / FailedOp EP).
5. [x] Fuzz de targets/calldata/depósitos en verde.
6. [x] Gas profiling documentado (UserOp vs EOA).
7. [x] NatSpec + custom errors en APIs públicas.
8. [x] `doc/SWC-AUDIT.md` sin vulnerabilidades en alcance v1.
---

## 12. Próximo paso

**Módulo v1 completo (Fases 0–6).** Posibles extensiones: account factory, guardians/recovery, VerifyingPaymaster con firma off-chain, timelock en owner del PM, invariantes Foundry.

**Nota:** usa `~/.foundry/bin/forge` (o antepón `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.

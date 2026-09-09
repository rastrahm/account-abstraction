# Planificación — Módulo 12: Account Abstraction (ERC-4337)

**Estado:** Fases **0–2** ✅ completadas. Fases **3–6** pendientes.  
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

- Interfaces: `IAccount`, `IPaymaster`, `IEntryPoint` (spec v0.6 / v0.7 según dependencia fijada en Fase 0).
- Autorización: `msg.sender == address(entryPoint)` en `validateUserOp` y handlers de ejecución.
- Firma: ECDSA secp256k1 sobre `userOpHash`; fallo → `InvalidUserOpSignature`.
- Paymaster: `validatePaymasterUserOp` verifica depósito en EntryPoint + timestamp/reglas; fallo → `PaymasterValidationFailed`.
- Nonces: gestión vía EntryPoint 2D (`getNonce(address,uint192)`), no inventar contador paralelo conflictivo.
- Ejecución fallida → `ExecutionFailed`; caller no-EntryPoint → `OnlyEntryPoint`.

---

## 4. Arquitectura prevista

```
12-account-abstraction/
├── doc/                              ← planificación y diagramas (esta carpeta)
├── src/
│   ├── account/
│   │   └── SmartAccount.sol          # IAccount: validateUserOp + execute
│   ├── paymaster/
│   │   └── SponsoringPaymaster.sol   # IPaymaster: validate + postOp
│   ├── validation/
│   │   └── SignatureValidator.sol    # ECDSA / userOpHash helpers
│   ├── interfaces/
│   │   ├── IAccount.sol
│   │   ├── IPaymaster.sol
│   │   ├── IEntryPoint.sol
│   │   └── UserOperation.sol         # struct PackedUserOperation / UserOperation
│   └── libraries/
│       └── UserOperationLib.sol      # hash / pack / unpack (opcional)
├── test/
│   ├── SmartAccount.t.sol
│   ├── Paymaster.t.sol
│   ├── UserOpE2E.t.sol
│   ├── UnauthorizedSender.t.sol
│   ├── gas/UserOp.gas.t.sol
│   └── fuzz/UserOp.fuzz.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── remappings.txt
```

### Contratos y responsabilidades

| Contrato / artefacto | Responsabilidad |
|----------------------|-----------------|
| `SmartAccount` | Valida UserOp (firma + nonce vía EP); ejecuta call(s) solo si llama EntryPoint |
| `SignatureValidator` | Recupera signer desde `userOpHash` + signature; compara con owner |
| `SponsoringPaymaster` | Decide sponsorship; exige depósito EP; `postOp` para liquidación/contabilidad |
| `IEntryPoint` (dep) | Orquesta simulación, validación, ejecución y cobro de gas |
| `UserOperation` / lib | Struct + hash canónico del UserOp |

---

## 5. Errores custom (obligatorios del módulo)

```solidity
error OnlyEntryPoint();
error ExecutionFailed();
error InvalidUserOpSignature();
error PaymasterValidationFailed();
```

Ampliar solo si hace falta (p. ej. `ZeroAddress()`, `PaymasterExpired()`, `InsufficientPaymasterDeposit()`), siempre como custom errors.

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
| 3 | `SmartAccount` (`validateUserOp` + execute) | ⏳ Pendiente | ❌ Sin autorizar |
| 4 | `SponsoringPaymaster` (validate + postOp + depósito) | ⏳ Pendiente | ❌ Sin autorizar |
| 5 | Suite e2e + unauthorized sender + fuzz | ⏳ Pendiente | ❌ Sin autorizar |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ⏳ Pendiente | ❌ Sin autorizar |

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

### Fase 3 — SmartAccount

**Objetivo:** cuenta ERC-4337 con validación y ejecución solo vía EntryPoint.

1. Tests primero: `validateUserOp` desde no-EP → `OnlyEntryPoint`.
2. `validateUserOp`: firma + (si aplica) missingAccountFunds / depósito.
3. `execute` / `executeBatch`: solo EntryPoint; fallo de call → `ExecutionFailed`.
4. Owner / inicialización segura; `immutable` EntryPoint.

**Criterio de salida:** validación + ejecución feliz; unauthorized sender cubierto.

---

### Fase 4 — SponsoringPaymaster

**Objetivo:** patrocinio de gas con reglas explícitas.

1. Tests: depósito insuficiente / expirado / regla fallida → `PaymasterValidationFailed`.
2. `validatePaymasterUserOp`: chequear depósito en EntryPoint + `validUntil` / whitelist / límites.
3. `postOp`: contabilidad post-ejecución (según modo).
4. Funciones admin (deposit/withdraw/stake) con access control.

**Criterio de salida:** UserOp patrocinada OK; caminos de rechazo en verde.

---

### Fase 5 — Suite e2e + unauthorized + fuzz

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | Struct UserOp → firma → EntryPoint → ejecución → deducción Paymaster |
| Unauthorized | `validateUserOp` / execute desde != EntryPoint → `OnlyEntryPoint` |
| Fuzz | targets, calldata, bounds de depósito Paymaster |

**Criterio de salida:** `forge test` verde; fuzz ≥ 1000 runs sin fallos inesperados.

---

### Fase 6 — Gas + Deploy + hardening

1. `script/Deploy.s.sol` (Account + Paymaster + funding EP).
2. `test/gas/UserOp.gas.t.sol`: overhead UserOp vs tx ECDSA EOA (órdenes de magnitud / deltas).
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md` al estilo de módulos previos.

**Criterio de salida:** deploy local reproducible + docs de seguridad + gas documentado.

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

- [ ] `msg.sender == entryPoint` en validación y ejecución.
- [ ] ECDSA sobre `userOpHash` canónico (sin malleability trivial mal manejada).
- [ ] Paymaster verifica depósito / stake según spec y reglas de negocio.
- [ ] Timestamps / `validUntil`–`validAfter` respetados.
- [ ] Custom errors del módulo.
- [ ] Sin floating pragma; NatSpec en APIs públicas.
- [ ] Suite unauthorized + fuzz + gas + (Fase 6) SWC-AUDIT.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido |
|---------|-----------|
| `planificacion.md` | Este documento (fases + gates) |
| `diagrama-de-clases.md` | Estructura y relaciones entre contratos |
| `diagrama-de-flujo.md` | Flujos de decisión (validación, paymaster, ejecución) |
| `flujograma.md` | Flujos actor–sistema extremo a extremo |
| `SWC-AUDIT.md` | Matriz SWC (Fase 6) |
| `GAS.md` | Optimizaciones y benchmarks (Fase 6) |

---

## 11. Criterios de aceptación del módulo

1. Compila con `pragma solidity 0.8.24`.
2. Account + Paymaster operativos vía EntryPoint con tests e2e.
3. Caller != EntryPoint no puede validar ni ejecutar.
4. Firma inválida y paymaster inválido revierten con custom errors.
5. Fuzz de targets/calldata/depósitos en verde.
6. Gas profiling documentado (UserOp vs EOA).
7. NatSpec + custom errors en APIs públicas.

---

## 12. Próximo paso

**Autorizar Fase 3** (`SmartAccount`: `validateUserOp` + `execute` solo vía EntryPoint).

**Nota:** usa `~/.foundry/bin/forge` (o antepón `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.

# Decisiones técnicas, lógica y gas — Módulo 12 (ERC-4337)

Documento para entender **qué se decidió**, **por qué**, **cómo fluye el sistema** y **dónde aún se puede ahorrar gas**.

**Alcance v1:** `SmartAccount` · `SignatureValidator` · `SponsoringPaymaster` · libs · EntryPoint v0.7 (eth-infinitism).

🇪🇸 Español · [🇬🇧 English](./DECISIONES-Y-LOGICA-EN.md)

Relacionado: [`flujograma-ES.md`](./flujograma-ES.md) · [`GAS-ES.md`](./GAS-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) · [`planificacion-ES.md`](./planificacion-ES.md)

---

## 1. Decisiones técnicas (y por qué)

### 1.1 Spec ERC-4337 **v0.7** (no v0.6)

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| `PackedUserOperation` | UserOp “unpacked” de v0.6 | Menos calldata (`accountGasLimits` / `gasFees` en `bytes32`); alineado a EntryPoint actual |
| Dep `account-abstraction@v0.7.0` | Reimplementar EntryPoint | No reinventar el orquestador; tests contra EP real |

### 1.2 Auth: solo EntryPoint

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| `msg.sender == entryPoint` en `validateUserOp`, `execute`, `executeBatch`, `withdrawDepositTo`, `validatePaymasterUserOp`, `postOp` | Permitir también al `owner` (como SimpleAccount sample) | Evita bypass: nadie ejecuta lógica de la cuenta sin pasar por el flujo AA |
| Custom error `OnlyEntryPoint` | `require` con string | Más barato + estilo monorepo |

**Implicación:** el owner firma UserOps off-chain; on-chain solo el EntryPoint “empuja” la ejecución.

### 1.3 Owner y EntryPoint **immutable**

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| `owner` / `entryPoint` immutable en la cuenta | Storage mutable + `transferOwnership` | Menos SLOAD en hot path; v1 simple |
| Sin factory / proxy de cuenta | CREATE2 factory + UUPS | Fuera de alcance v1; rotar owner = redeploy |

### 1.4 Firma ECDSA + prefijo `personal_sign`

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Hash firmado = `toEthSignedMessageHash(userOpHash)` | Firmar el `userOpHash` crudo | Compatible con wallets / sample SimpleAccount AA |
| OZ `tryRecover` | `ecrecover` manual | Rechaza malleability (`s` alto) y length inválida |
| Soft-fail → `SIG_VALIDATION_FAILED` (1) | `revert InvalidUserOpSignature` en `validateUserOp` | La spec pide no revertir por firma mala en validación (simulación bundler) |

`validateSignature` (con revert) existe para usos fuera del path EntryPoint; la cuenta usa `toValidationData`.

### 1.5 Nonce: solo EntryPoint 2D

| Decisión | Motivo |
|----------|--------|
| No llevar contador propio en la cuenta | El EP ya garantiza unicidad con `getNonce(address, uint192)` |
| Tests e2e AA25 | Replay de la misma UserOp debe fallar |

### 1.6 Paymaster: reglas on-chain (whitelist)

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Whitelist `isSponsored` + depósito EP + `maxCostPerOp` + ventana tiempo | Solo firma off-chain (VerifyingPaymaster) | Reglas explícitas y testeables sin servicio externo |
| `Ownable2Step` en el PM | Ownable simple | Rotación de ownership más segura |
| `block.timestamp` + `validationData` | Solo `validationData` (recomendación AA) | Cumplir planificación del módulo (rechazo explícito `PaymasterValidationFailed`) **y** dejar que el EP también enforce la ventana |

### 1.7 Ejecución

| Decisión | Motivo |
|----------|--------|
| `execute` / `executeBatch` con `.call` | Genérico: cualquier target/calldata |
| Fallo → `ExecutionFailed` (sin bubble de returndata) | Simple y predecible; el EP igual liquida gas si la UserOp llegó a ejecutar |
| Batch: `values.length == 0` ⇒ value 0 | Ahorra calldata cuando no se manda ETH |

### 1.8 Errores y layout

- Custom errors del módulo (no strings).
- Pragma fijo `0.8.24`.
- Interfaces del módulo como aliases tipados sobre AA (imports estables).
- Hash propio en `UserOperationLib` verificado contra `EntryPoint.getUserOpHash` (fuzz 1000).

---

## 2. Lógica que sigue el sistema

### 2.1 Piezas

```text
Owner (EOA)  --firma-->  UserOp
                |
                v
           Bundler / test
                |
                v
         EntryPoint.handleOps
           |            |
           v            v
     SmartAccount   SponsoringPaymaster (opcional)
     validateUserOp   validatePaymasterUserOp
           |            |
           +---- execute (callData) ----+
                        |
                        v
                 postOp (si hubo PM)
                        |
                        v
              Cobro gas (cuenta o PM) → beneficiary
```

### 2.2 Ciclo feliz (sin paymaster)

1. **Build:** `sender = SmartAccount`, `nonce = EP.getNonce(account, 0)`, `callData = execute(target, value, data)`, gas packs v0.7, `paymasterAndData` vacío.
2. **Hash:** `userOpHash = EntryPoint.getUserOpHash(userOp)` (= lib del módulo).
3. **Sign:** owner firma el eth-signed hash → `userOp.signature`.
4. **handleOps:**
   - EP llama `account.validateUserOp` → comprueba `msg.sender == EP`, ECDSA, opcionalmente manda `missingAccountFunds` al EP.
   - EP consume nonce.
   - EP ejecuta `callData` en la cuenta → `execute` → `.call` al target.
   - EP cobra gas del **depósito de la cuenta** y paga al `beneficiary`.

### 2.3 Ciclo feliz (con paymaster)

Igual, pero `paymasterAndData` =  
`paymaster (20) || verGas (16) || postOpGas (16) || validUntil (6) || validAfter (6)`.

Tras validar la cuenta, el EP:

1. Comprueba depósito del paymaster (≥ maxCost).
2. Llama `validatePaymasterUserOp` → whitelist, tope, tiempo, arma `context`.
3. Ejecuta la cuenta.
4. Llama `postOp` → contabiliza `totalSponsoredGasCost`.
5. Cobra gas al **paymaster** (la cuenta no baja su depósito por esa op).

### 2.4 Caminos de rechazo (resumen)

| Situación | Qué pasa |
|-----------|----------|
| Alguien ≠ EP llama validate/execute | `OnlyEntryPoint` |
| Firma mala en validateUserOp | `validationData = 1` → EP `AA24` |
| Nonce repetido | EP `AA25` |
| Target call falla | `ExecutionFailed` (EP igual puede asentar la op / cobrar gas) |
| Sender no whitelisteado / depósito PM bajo / expirado | `PaymasterValidationFailed` → EP `AA33` / `AA31` |

### 2.5 Invariante de seguridad central

> **Toda mutación privilegiada de la cuenta pasa por EntryPoint.**  
> La firma del owner autoriza la UserOp; no autoriza llamadas directas al contrato.

---

## 3. ¿Se puede mejorar el gas de lo que existe?

Sí, pero hay que separar **dos capas**.

### 3.1 Lo que ya no es “nuestro” overhead

El salto EOA (~55k) → UserOp (~160k) / UserOp+PM (~200k) en el snapshot viene **sobre todo del EntryPoint** (`handleOps`, eventos, contabilidad).  
Optimizar solo `SmartAccount.execute` no va a bajar el UserOp a costo de EOA: **AA siempre paga ese peaje**.

Ver números: [`GAS-ES.md`](./GAS-ES.md).

### 3.2 Mejoras realistas **dentro** del módulo (v1 → v1.x)

| Mejora | Dónde | Impacto esperado | Costo / riesgo |
|--------|-------|------------------|----------------|
| Quitar `totalSponsoredGasCost +=` (o acumular off-chain vía eventos) | `postOp` | Ahorra 1 SSTORE por UserOp patrocinada | Menos métrica on-chain |
| No chequear `block.timestamp` on-chain; solo devolver `validationData` | Paymaster | Menos ops + alineación a best practice AA | Pierde revert explícito `PaymasterValidationFailed` por tiempo |
| Whitelist con bitmap / merkle / firma del verifyingSigner | Paymaster | Menos SLOAD o menos storage writes al alta | Más complejidad (estilo VerifyingPaymaster) |
| Assembly en `_call` / early `codesize` checks selectivos | Account | Micro-ahorro | Legibilidad |
| Empaquetar `context` más corto (`abi.encodePacked` fijo) | Paymaster | Menos memory en postOp | Parsing más frágil |
| `execute` sin copiar `data` a memory (ya es `calldata`) — OK hoy; batch igual | Account | Ya razonable | — |
| Account factory + clones (EIP-1167) | Deploy | Deploy de cuentas mucho más barato | No baja el gas de cada UserOp |

### 3.3 Mejoras de **producto** que también ayudan al gas operativo

| Idea | Efecto |
|------|--------|
| Session keys / validación más barata que ECDSA secp256k1 | Baja `validateUserOp` (hoy ~36k aislado) |
| Aggregator de firmas (ERC-4337) | Amortiza verificación en batch |
| Límites de gas UserOp bien estimados | Menos prefund / menos fallos AA26/AA36 |
| No usar paymaster si la cuenta ya tiene depósito | Evita ~40k de path PM + postOp |

### 3.4 Qué **no** conviene “optimizar” a ciegas

| Tentación | Por qué no |
|-----------|------------|
| Quitar `OnlyEntryPoint` | Rompe el modelo de seguridad |
| Soft-fail → revert siempre en validate | Empeora simulación bundler |
| Reimplementar EntryPoint “más liviano” | Fuera de alcance; riesgo de incompatibilidad |
| Bajar `optimizer_runs` sin medir | Puede subir el hot path |

### 3.5 Orden sugerido si se abre una fase de gas v2

1. Medir otra vez con `forge test --match-contract UserOpGasTest --gas-report` (baseline).
2. Quitar o externalizar `totalSponsoredGasCost` (quick win en path +PM).
3. Evaluar paymaster solo-`validationData` (sin `block.timestamp`).
4. Si el producto lo pide: VerifyingPaymaster / session keys (ahorro estructural, no cosmético).

---

## 4. Mapa mental en una frase

> **El owner firma; el EntryPoint manda; la cuenta solo obedece al EntryPoint; el paymaster solo paga si las reglas on-chain pasan; el gas extra vs EOA es el precio del protocolo AA, no un bug del `setValue`.**

---

## 5. Referencias rápidas en código

| Tema | Archivo |
|------|---------|
| Auth + execute | `src/account/SmartAccount.sol` |
| ECDSA | `src/validation/SignatureValidator.sol` |
| Sponsorship | `src/paymaster/SponsoringPaymaster.sol` |
| Hash ≡ EP | `src/libraries/UserOperationLib.sol` |
| E2E lógica | `test/UserOpE2E.t.sol` |
| Gas medido | `test/gas/UserOp.gas.t.sol` · `.gas-snapshot` |

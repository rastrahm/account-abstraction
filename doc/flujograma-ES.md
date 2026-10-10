# Flujograma — Ciclo completo ERC-4337 (Account + Paymaster)

🇪🇸 Español · [🇬🇧 English](./flujograma-EN.md)

Flujo extremo a extremo entre actores y contratos (módulo 12, **v1 final**): construcción de UserOp, firma, validación, ejecución y liquidación de gas.

## Actores

| Actor | Rol |
|-------|-----|
| Owner | Controla la Smart Account; firma el `userOpHash` |
| Usuario / dApp | Define la intención (target + calldata) |
| Bundler / Tester | Empaqueta y envía `handleOps` al EntryPoint (en tests: Foundry) |
| EntryPoint | Orquesta validación, ejecución y cobro de gas |
| SmartAccount | Valida firma y ejecuta llamadas |
| SponsoringPaymaster | Patrocina gas si las reglas pasan |
| SignatureValidator | Recupera y verifica ECDSA |
| CI / Foundry | Unit, unauthorized, fuzz, gas profiling |

---

## Flujograma principal — Build → Sign → Validate → Execute → Settle

```mermaid
flowchart TD
    Start([Inicio]) --> Intent[Usuario define target + calldata]
    Intent --> Build[Armar UserOperation\nsender=SmartAccount, nonce EP, gas]
    Build --> Hash[EntryPoint.getUserOpHash / lib.hash]
    Hash --> Sign[Owner firma userOpHash ECDSA]
    Sign --> Submit[handleOps vía Bundler o test]
    Submit --> AuthAcc{Account: msg.sender == EP?}
    AuthAcc -->|No| RejEP[OnlyEntryPoint]
    AuthAcc -->|Sí| SigOK{¿firma válida?}
    SigOK -->|No| RejSig[InvalidUserOpSignature]
    SigOK -->|Sí| HasPM{¿paymasterAndData vacío?}

    HasPM -->|Sí| FundAcc[Cuenta cubre gas\ndeposito EP si hace falta]
    HasPM -->|No| AuthPM{Paymaster: msg.sender == EP?}
    AuthPM -->|No| RejEP
    AuthPM -->|Sí| Rules{¿depósito + reglas + tiempo OK?}
    Rules -->|No| RejPM[PaymasterValidationFailed]
    Rules -->|Sí| Ctx[Context + validationData OK]

    FundAcc --> Exec[Ejecutar callData en SmartAccount]
    Ctx --> Exec
    Exec --> ExecOK{¿call success?}
    ExecOK -->|No| RejExec[ExecutionFailed]
    ExecOK -->|Sí| Post{¿hubo paymaster?}
    Post -->|Sí| PostOp[paymaster.postOp]
    Post -->|No| Charge[EntryPoint cobra gas a la cuenta]
    PostOp --> ChargePM[EntryPoint cobra gas al Paymaster]
    Charge --> End([Fin — UserOp exitosa])
    ChargePM --> End

    RejEP --> EndFail([Fin — rechazo])
    RejSig --> EndFail
    RejPM --> EndFail
    RejExec --> EndFail
```

---

## Flujograma — Deploy y funding

```mermaid
flowchart TD
    A([Deploy]) --> B[Deploy EntryPoint\no usar referencia fija de tests]
    B --> C[Deploy SmartAccount\nentryPoint + owner]
    C --> D[Deploy SponsoringPaymaster]
    D --> E[Paymaster.deposit / addStake en EP]
    E --> F[Opcional: depositTo Account]
    F --> G([Listo para handleOps])
```

---

## Flujograma — Unauthorized sender (ataque / misuse)

```mermaid
flowchart TD
    A[Attacker llama validateUserOp\ndirecto en SmartAccount] --> B{msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Sí| D[No aplica: solo EP llega aquí]

    E[Attacker llama execute directo] --> F{msg.sender == entryPoint?}
    F -->|No| G[Revert OnlyEntryPoint]
    F -->|Sí| H[Ejecución legítima vía EP]
```

---

## Secuencia simplificada (e2e feliz con Paymaster)

```mermaid
sequenceDiagram
    actor Owner
    participant Test as Bundler/Test
    participant EP as EntryPoint
    participant Acc as SmartAccount
    participant Sig as SignatureValidator
    participant PM as SponsoringPaymaster

    Owner->>Test: UserOp firmada
    Test->>EP: handleOps([userOp])
    EP->>Acc: validateUserOp(userOp, hash, funds)
    Acc->>Sig: recover / isValidSignature
    Sig-->>Acc: OK
    Acc-->>EP: validationData
    EP->>PM: validatePaymasterUserOp(...)
    PM-->>EP: context, validationData
    EP->>Acc: execute via callData
    Acc-->>EP: success
    EP->>PM: postOp(mode, context, actualGasCost)
    EP-->>Test: eventos / gas settled
```

---

## Trazabilidad con fases

| Tramo del flujograma | Fase | Estado |
|----------------------|------|--------|
| Setup EP + carpetas + deps | 0 | ✅ |
| Struct UserOp + hash + interfaces | 1 | ✅ |
| Firma ECDSA | 2 | ✅ |
| Account validate + execute | 3 | ✅ |
| Paymaster validate + postOp + deposit | 4 | ✅ |
| E2E + unauthorized + fuzz | 5 | ✅ |
| Gas vs EOA + Deploy + SWC | 6 | ✅ |

**Módulo v1 completo.**

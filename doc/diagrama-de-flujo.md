# Diagrama de flujo — Validación, Paymaster y ejecución

Flujos de decisión internos del sistema Account Abstraction (módulo 12).

## 1. `validateUserOp` en SmartAccount

```mermaid
flowchart TD
    A[EntryPoint llama validateUserOp] --> B{¿msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Sí| D[Obtener signature del UserOp]
    D --> E[SignatureValidator: recover signer]
    E --> F{¿signer == owner?}
    F -->|No| G[Revert InvalidUserOpSignature\no validationData = SIG_VALIDATION_FAILED]
    F -->|Sí| H{¿missingAccountFunds > 0?}
    H -->|Sí| I[Depositar / transferir fondos al EntryPoint]
    H -->|No| J[Omitir depósito]
    I --> K[Retornar validationData OK]
    J --> K
    C --> Z[Fin]
    G --> Z
    K --> Z
```

## 2. `validatePaymasterUserOp`

```mermaid
flowchart TD
    A[EntryPoint llama validatePaymasterUserOp] --> B{¿msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Sí| D[Leer paymasterAndData / reglas]
    D --> E{¿timestamp dentro de validAfter–validUntil?}
    E -->|No| F[Revert PaymasterValidationFailed]
    E -->|Sí| G{¿reglas de sponsorship OK?\nwhitelist / límites / etc.}
    G -->|No| F
    G -->|Sí| H{¿depósito EP >= maxCost?}
    H -->|No| F
    H -->|Sí| I[Armar context + validationData]
    I --> J[Retornar context, validationData]
    C --> Z[Fin]
    F --> Z
    J --> Z
```

## 3. Ejecución (`execute` / `executeBatch`)

```mermaid
flowchart TD
    A[Calldata de ejecución en Account] --> B{¿msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Sí| D[target.call / batch]
    D --> E{¿success?}
    E -->|No| F[Revert ExecutionFailed]
    E -->|Sí| G[Efectos de negocio aplicados]
    C --> Z[Fin]
    F --> Z
    G --> Z
```

## 4. Ciclo de estados — UserOperation

```mermaid
stateDiagram-v2
    [*] --> Built: Cliente arma UserOp\n(sender, nonce, callData, gas, paymasterAndData)

    Built --> Signed: Owner firma userOpHash
    Signed --> Submitted: Bundler / tester envía a EntryPoint.handleOps

    Submitted --> AccountValidation: validateUserOp
    AccountValidation --> RejectedSig: InvalidUserOpSignature
    AccountValidation --> PaymasterValidation: si hay paymaster

    PaymasterValidation --> RejectedPM: PaymasterValidationFailed
    PaymasterValidation --> Execution: simulate/execute callData
    AccountValidation --> Execution: sin paymaster\n(cuenta paga gas)

    Execution --> FailedExec: ExecutionFailed
    Execution --> PostOp: paymaster.postOp si aplica
    PostOp --> Settled: cobro gas / eventos
    Execution --> Settled: sin paymaster

    RejectedSig --> [*]
    RejectedPM --> [*]
    FailedExec --> [*]
    Settled --> [*]
```

## 5. Autorización EntryPoint (regla transversal)

```mermaid
flowchart LR
    X[Cualquier llamada sensible] --> Y{msg.sender == entryPoint?}
    Y -->|Sí| OK[Continuar lógica]
    Y -->|No| NO[OnlyEntryPoint]
```

Aplica a: `validateUserOp`, `execute`/`executeBatch`, `validatePaymasterUserOp`, `postOp`.

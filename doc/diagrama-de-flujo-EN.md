# Flow diagram — Validation, Paymaster and execution

[🇪🇸 Español](./diagrama-de-flujo-ES.md) · 🇬🇧 English

Internal decision flows of the Account Abstraction system (module 12, **final v1**).

## 1. `validateUserOp` in SmartAccount

```mermaid
flowchart TD
    A[EntryPoint calls validateUserOp] --> B{msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Yes| D[Get signature from UserOp]
    D --> E[SignatureValidator: recover signer]
    E --> F{signer == owner?}
    F -->|No| G[Revert InvalidUserOpSignature\nor validationData = SIG_VALIDATION_FAILED]
    F -->|Yes| H{missingAccountFunds > 0?}
    H -->|Yes| I[Deposit / transfer funds to EntryPoint]
    H -->|No| J[Skip deposit]
    I --> K[Return validationData OK]
    J --> K
    C --> Z[End]
    G --> Z
    K --> Z
```

## 2. `validatePaymasterUserOp`

```mermaid
flowchart TD
    A[EntryPoint calls validatePaymasterUserOp] --> B{msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Yes| D[Read paymasterAndData / rules]
    D --> E{timestamp within validAfter–validUntil?}
    E -->|No| F[Revert PaymasterValidationFailed]
    E -->|Yes| G{sponsorship rules OK?\nwhitelist / limits / etc.}
    G -->|No| F
    G -->|Yes| H{EP deposit >= maxCost?}
    H -->|No| F
    H -->|Yes| I[Build context + validationData]
    I --> J[Return context, validationData]
    C --> Z[End]
    F --> Z
    J --> Z
```

## 3. Execution (`execute` / `executeBatch`)

```mermaid
flowchart TD
    A[Execution calldata on Account] --> B{msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Yes| D[target.call / batch]
    D --> E{success?}
    E -->|No| F[Revert ExecutionFailed]
    E -->|Yes| G[Business effects applied]
    C --> Z[End]
    F --> Z
    G --> Z
```

## 4. State cycle — UserOperation

```mermaid
stateDiagram-v2
    [*] --> Built: Client builds UserOp\n(sender, nonce, callData, gas, paymasterAndData)

    Built --> Signed: Owner signs userOpHash
    Signed --> Submitted: Bundler / tester sends to EntryPoint.handleOps

    Submitted --> AccountValidation: validateUserOp
    AccountValidation --> RejectedSig: InvalidUserOpSignature
    AccountValidation --> PaymasterValidation: if there is a paymaster

    PaymasterValidation --> RejectedPM: PaymasterValidationFailed
    PaymasterValidation --> Execution: simulate/execute callData
    AccountValidation --> Execution: no paymaster\n(account pays gas)

    Execution --> FailedExec: ExecutionFailed
    Execution --> PostOp: paymaster.postOp if applicable
    PostOp --> Settled: gas charge / events
    Execution --> Settled: no paymaster

    RejectedSig --> [*]
    RejectedPM --> [*]
    FailedExec --> [*]
    Settled --> [*]
```

## 5. EntryPoint authorization (cross-cutting rule)

```mermaid
flowchart LR
    X[Any sensitive call] --> Y{msg.sender == entryPoint?}
    Y -->|Yes| OK[Continue logic]
    Y -->|No| NO[OnlyEntryPoint]
```

Applies to: `validateUserOp`, `execute`/`executeBatch`, `withdrawDepositTo`, `validatePaymasterUserOp`, `postOp`.

# Flowchart — Full ERC-4337 cycle (Account + Paymaster)

[🇪🇸 Español](./flujograma-ES.md) · 🇬🇧 English

End-to-end flow between actors and contracts (module 12, **final v1**): UserOp construction, signing, validation, execution and gas settlement.

## Actors

| Actor | Role |
|-------|------|
| Owner | Controls the Smart Account; signs the `userOpHash` |
| User / dApp | Defines the intent (target + calldata) |
| Bundler / Tester | Packs and sends `handleOps` to the EntryPoint (in tests: Foundry) |
| EntryPoint | Orchestrates validation, execution and gas charging |
| SmartAccount | Validates the signature and executes calls |
| SponsoringPaymaster | Sponsors gas if the rules pass |
| SignatureValidator | Recovers and verifies ECDSA |
| CI / Foundry | Unit, unauthorized, fuzz, gas profiling |

---

## Main flowchart — Build → Sign → Validate → Execute → Settle

```mermaid
flowchart TD
    Start([Start]) --> Intent[User defines target + calldata]
    Intent --> Build[Build UserOperation\nsender=SmartAccount, EP nonce, gas]
    Build --> Hash[EntryPoint.getUserOpHash / lib.hash]
    Hash --> Sign[Owner signs userOpHash ECDSA]
    Sign --> Submit[handleOps via Bundler or test]
    Submit --> AuthAcc{Account: msg.sender == EP?}
    AuthAcc -->|No| RejEP[OnlyEntryPoint]
    AuthAcc -->|Yes| SigOK{valid signature?}
    SigOK -->|No| RejSig[InvalidUserOpSignature]
    SigOK -->|Yes| HasPM{paymasterAndData empty?}

    HasPM -->|Yes| FundAcc[Account covers gas\nEP deposit if needed]
    HasPM -->|No| AuthPM{Paymaster: msg.sender == EP?}
    AuthPM -->|No| RejEP
    AuthPM -->|Yes| Rules{deposit + rules + time OK?}
    Rules -->|No| RejPM[PaymasterValidationFailed]
    Rules -->|Yes| Ctx[Context + validationData OK]

    FundAcc --> Exec[Execute callData on SmartAccount]
    Ctx --> Exec
    Exec --> ExecOK{call success?}
    ExecOK -->|No| RejExec[ExecutionFailed]
    ExecOK -->|Yes| Post{was there a paymaster?}
    Post -->|Yes| PostOp[paymaster.postOp]
    Post -->|No| Charge[EntryPoint charges gas to the account]
    PostOp --> ChargePM[EntryPoint charges gas to the Paymaster]
    Charge --> End([End — successful UserOp])
    ChargePM --> End

    RejEP --> EndFail([End — rejected])
    RejSig --> EndFail
    RejPM --> EndFail
    RejExec --> EndFail
```

---

## Flowchart — Deploy and funding

```mermaid
flowchart TD
    A([Deploy]) --> B[Deploy EntryPoint\nor use fixed test reference]
    B --> C[Deploy SmartAccount\nentryPoint + owner]
    C --> D[Deploy SponsoringPaymaster]
    D --> E[Paymaster.deposit / addStake in EP]
    E --> F[Optional: depositTo Account]
    F --> G([Ready for handleOps])
```

---

## Flowchart — Unauthorized sender (attack / misuse)

```mermaid
flowchart TD
    A[Attacker calls validateUserOp\ndirectly on SmartAccount] --> B{msg.sender == entryPoint?}
    B -->|No| C[Revert OnlyEntryPoint]
    B -->|Yes| D[Not applicable: only EP gets here]

    E[Attacker calls execute directly] --> F{msg.sender == entryPoint?}
    F -->|No| G[Revert OnlyEntryPoint]
    F -->|Yes| H[Legitimate execution via EP]
```

---

## Simplified sequence (happy e2e with Paymaster)

```mermaid
sequenceDiagram
    actor Owner
    participant Test as Bundler/Test
    participant EP as EntryPoint
    participant Acc as SmartAccount
    participant Sig as SignatureValidator
    participant PM as SponsoringPaymaster

    Owner->>Test: Signed UserOp
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
    EP-->>Test: events / gas settled
```

---

## Traceability with phases

| Flowchart segment | Phase | Status |
|-------------------|-------|--------|
| EP setup + folders + deps | 0 | ✅ |
| UserOp struct + hash + interfaces | 1 | ✅ |
| ECDSA signature | 2 | ✅ |
| Account validate + execute | 3 | ✅ |
| Paymaster validate + postOp + deposit | 4 | ✅ |
| E2E + unauthorized + fuzz | 5 | ✅ |
| Gas vs EOA + Deploy + SWC | 6 | ✅ |

**Module v1 complete.**

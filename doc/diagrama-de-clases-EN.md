# Class diagram — Account Abstraction (ERC-4337)

[🇪🇸 Español](./diagrama-de-clases-ES.md) · 🇬🇧 English

Structural view of contracts, interfaces and relationships (module 12, **final v1**).

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class IEntryPoint {
        <<interface AA v0.7>>
        +handleOps(ops, beneficiary)
        +getUserOpHash(userOp) bytes32
        +getNonce(sender, key) uint256
        +depositTo(account)
        +balanceOf(account) uint256
        +withdrawTo(withdrawAddress, amount)
    }

    class IAccount {
        <<interface>>
        +validateUserOp(userOp, userOpHash, missingAccountFunds) uint256
    }

    class IPaymaster {
        <<interface>>
        +validatePaymasterUserOp(userOp, userOpHash, maxCost) context_validationData
        +postOp(mode, context, actualGasCost, actualUserOpFeePerGas)
    }

    class PackedUserOperation {
        <<struct v0.7>>
        +address sender
        +uint256 nonce
        +bytes initCode
        +bytes callData
        +bytes32 accountGasLimits
        +uint256 preVerificationGas
        +bytes32 gasFees
        +bytes paymasterAndData
        +bytes signature
    }

    class SignatureValidator {
        <<library>>
        +recoverSigner(userOpHash, signature) address
        +isValidSignature(userOpHash, signature, owner) bool
        +validateSignature(userOpHash, signature, owner)
        +toValidationData(userOpHash, signature, owner) uint256
    }

    class SmartAccount {
        <<contract>>
        +IEntryPoint entryPoint$
        +address owner$
        +constructor(entryPoint, owner)
        +validateUserOp(userOp, userOpHash, missingAccountFunds) uint256
        +execute(target, value, data)
        +executeBatch(targets, values, datas)
        +addDeposit()
        +withdrawDepositTo(withdrawAddress, amount)
        +getNonce() uint256
        +getDeposit() uint256
    }

    class SponsoringPaymaster {
        <<contract Ownable2Step>>
        +IEntryPoint entryPoint$
        +uint256 maxCostPerOp
        +uint256 totalSponsoredGasCost
        +mapping isSponsored
        +constructor(entryPoint)
        +setSponsored(account, allowed)
        +setMaxCostPerOp(maxCostPerOp)
        +validatePaymasterUserOp(userOp, userOpHash, maxCost) context_validationData
        +postOp(mode, context, actualGasCost, feePerGas)
        +deposit()
        +withdrawTo(withdrawAddress, amount)
        +addStake(unstakeDelaySec)
    }

    class UserOperationLib {
        <<library>>
        +packAccountGasLimits(verGas, callGas) bytes32
        +packGasFees(priority, maxFee) bytes32
        +packPaymasterAndData(...) bytes
        +hash(userOp) bytes32
        +getUserOpHash(userOp, entryPoint, chainId) bytes32
    }

    class ValidationDataLib {
        <<library>>
        +SIG_VALIDATION_SUCCESS$
        +SIG_VALIDATION_FAILED$
        +pack(sigFailed, validUntil, validAfter) uint256
        +parse(validationData) aggregator_after_until
    }

    IAccount <|.. SmartAccount : implements
    IPaymaster <|.. SponsoringPaymaster : implements
    SmartAccount --> IEntryPoint : only callable by
    SponsoringPaymaster --> IEntryPoint : deposit / validate via
    SmartAccount --> SignatureValidator : uses
    SignatureValidator --> ValidationDataLib : toValidationData
    SmartAccount ..> PackedUserOperation : validates
    SponsoringPaymaster ..> PackedUserOperation : sponsors
    UserOperationLib ..> PackedUserOperation : hashes / packs
    IEntryPoint ..> IAccount : validateUserOp
    IEntryPoint ..> IPaymaster : validatePaymasterUserOp / postOp
```

---

## Key relationships

| Relationship | Type | Note |
|--------------|------|------|
| `SmartAccount` → `IAccount` | implementation | ERC-4337 v0.7 account |
| `SponsoringPaymaster` → `IPaymaster` | implementation | Gas sponsorship |
| Account / Paymaster → `IEntryPoint` | auth + deps | Only the EntryPoint invokes validate/execute/postOp |
| `SmartAccount` → `SignatureValidator` | library | ECDSA over `userOpHash` |
| `UserOperationLib` → EntryPoint hash | compatibility | `getUserOpHash` ≡ EP |

---

## Design notes (v1)

- `entryPoint` and `owner` (account) / `entryPoint` (PM) are **immutable**.
- Spec: **ERC-4337 v0.7** — `PackedUserOperation`.
- `SignatureValidator` is a **library** (stateless).
- Errors: `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, `ZeroAddress`, `InvalidBatchLength`.
- Paymaster admin: OpenZeppelin `Ownable2Step`.

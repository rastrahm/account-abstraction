# Diagrama de clases — Account Abstraction (ERC-4337)

🇪🇸 Español · [🇬🇧 English](./diagrama-de-clases-EN.md)

Vista estructural de contratos, interfaces y relaciones (módulo 12, **v1 final**).

## Diagrama (Mermaid)

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

## Relaciones clave

| Relación | Tipo | Nota |
|----------|------|------|
| `SmartAccount` → `IAccount` | implementación | Cuenta ERC-4337 v0.7 |
| `SponsoringPaymaster` → `IPaymaster` | implementación | Patrocinio de gas |
| Account / Paymaster → `IEntryPoint` | auth + deps | Solo EntryPoint invoca validate/execute/postOp |
| `SmartAccount` → `SignatureValidator` | library | ECDSA sobre `userOpHash` |
| `UserOperationLib` → EntryPoint hash | compatibilidad | `getUserOpHash` ≡ EP |

---

## Notas de diseño (v1)

- `entryPoint` y `owner` (cuenta) / `entryPoint` (PM) son **immutable**.
- Spec: **ERC-4337 v0.7** — `PackedUserOperation`.
- `SignatureValidator` es **library** (sin estado).
- Errores: `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, `ZeroAddress`, `InvalidBatchLength`.
- Paymaster admin: OpenZeppelin `Ownable2Step`.

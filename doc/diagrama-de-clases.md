# Diagrama de clases — Account Abstraction (ERC-4337)

Vista estructural de contratos, interfaces y relaciones (módulo 12).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class IEntryPoint {
        <<interface>>
        +handleOps(ops, beneficiary)
        +getUserOpHash(userOp) bytes32
        +getNonce(sender, key) uint256
        +depositTo(account)
        +balanceOf(account) uint256
    }

    class IAccount {
        <<interface>>
        +validateUserOp(userOp, userOpHash, missingAccountFunds) uint256
    }

    class IPaymaster {
        <<interface>>
        +validatePaymasterUserOp(userOp, userOpHash, maxCost) context_validationData
        +postOp(mode, context, actualGasCost)
    }

    class UserOperation {
        <<struct>>
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
        <<library_or_contract>>
        +isValidSignature(userOpHash, signature, owner) bool
        +recoverSigner(userOpHash, signature) address
    }

    class SmartAccount {
        <<contract>>
        -address owner
        -IEntryPoint entryPoint
        +constructor(entryPoint, owner)
        +validateUserOp(userOp, userOpHash, missingAccountFunds) uint256
        +execute(target, value, data)
        +executeBatch(targets, values, datas)
        +entryPoint() IEntryPoint
        -_requireFromEntryPoint()
        -_validateSignature(userOpHash, signature) uint256
    }

    class SponsoringPaymaster {
        <<contract>>
        -address owner
        -IEntryPoint entryPoint
        -uint48 validUntilDefault
        +constructor(entryPoint)
        +validatePaymasterUserOp(userOp, userOpHash, maxCost) context_validationData
        +postOp(mode, context, actualGasCost)
        +deposit()
        +withdrawTo(withdrawAddress, amount)
        +addStake(unstakeDelaySec)
        -_requireFromEntryPoint()
        -_validateSponsorship(userOp, maxCost)
    }

    class UserOperationLib {
        <<library>>
        +hash(userOp) bytes32
        +getSender(userOp) address
    }

    IAccount <|.. SmartAccount : implements
    IPaymaster <|.. SponsoringPaymaster : implements
    SmartAccount --> IEntryPoint : only callable by
    SponsoringPaymaster --> IEntryPoint : deposit / validate via
    SmartAccount --> SignatureValidator : uses
    SmartAccount ..> UserOperation : validates
    SponsoringPaymaster ..> UserOperation : sponsors
    UserOperationLib ..> UserOperation : hashes
    IEntryPoint ..> IAccount : validateUserOp
    IEntryPoint ..> IPaymaster : validatePaymasterUserOp / postOp
```

---

## Relaciones clave

| Relación | Tipo | Nota |
|----------|------|------|
| `SmartAccount` → `IAccount` | implementación | Contrato de cuenta ERC-4337 |
| `SponsoringPaymaster` → `IPaymaster` | implementación | Patrocinio de gas |
| `SmartAccount` / `Paymaster` → `IEntryPoint` | dependencia + auth | Solo EntryPoint puede invocar validación/ejecución/`postOp` |
| `SmartAccount` → `SignatureValidator` | uso | ECDSA sobre `userOpHash` |
| `IEntryPoint` → Account / Paymaster | orquestación | `handleOps` dispara el ciclo completo |

---

## Notas de diseño

- `entryPoint` y (si aplica) `owner` iniciales como `immutable` / set-once para gas y seguridad.
- La forma exacta del struct (`UserOperation` vs `PackedUserOperation`) se fija en **Fase 0/1** según la versión ERC-4337 elegida.
- `SignatureValidator` puede ser library pura o contrato helper; preferir library si no necesita estado.
- Errores del módulo: `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`.

pragma solidity 0.8.24;

/**
 * @title UserOperation (documentación ERC-4337 v0.7)
 * @notice El UserOp canónico de este módulo es `PackedUserOperation`
 *         (`account-abstraction/interfaces/PackedUserOperation.sol`).
 *
 * @dev Campos del struct:
 * - `sender` — cuenta que ejecuta
 * - `nonce` — nonce 2D del EntryPoint (`getNonce(address,uint192)`)
 * - `initCode` — factory+data si hay despliegue; vacío si la cuenta existe
 * - `callData` — llamada a ejecutar en la cuenta
 * - `accountGasLimits` — high128 `verificationGasLimit` | low128 `callGasLimit`
 * - `preVerificationGas` — overhead del bundler / `handleOps`
 * - `gasFees` — high128 `maxPriorityFeePerGas` | low128 `maxFeePerGas`
 * - `paymasterAndData` — paymaster (20) + verGas (16) + postOpGas (16) + data
 * - `signature` — firma sobre `userOpHash` (excluida del hash interno `encode`)
 *
 * Helpers de pack/hash: `src/libraries/UserOperationLib.sol`.
 */
library UserOperationDocs {
    /// @notice Identificador de spec fijada en Fase 0/1.
    string internal constant SPEC = "ERC-4337-v0.7-PackedUserOperation";
}

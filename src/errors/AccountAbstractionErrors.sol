pragma solidity 0.8.24;

/**
 * @title AccountAbstractionErrors
 * @notice Custom errors del módulo 12 (ERC-4337).
 */

/// @notice Caller distinto del EntryPoint autorizado.
error OnlyEntryPoint();

/// @notice La ejecución del `callData` / `execute` falló.
error ExecutionFailed();

/// @notice Firma ECDSA inválida o signer distinto del owner.
error InvalidUserOpSignature();

/// @notice El paymaster rechazó sponsorship (reglas, depósito o tiempo).
error PaymasterValidationFailed();

/// @notice Dirección cero donde no está permitida.
error ZeroAddress();

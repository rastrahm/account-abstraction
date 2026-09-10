pragma solidity 0.8.24;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib as AAUserOperationLib} from "account-abstraction/core/UserOperationLib.sol";

/**
 * @title UserOperationLib
 * @notice Packing, unpacking y hash de `PackedUserOperation` compatible con EntryPoint v0.7.
 * @dev `encode` / `hash` replican eth-infinitism; `getUserOpHash` replica
 *      `EntryPoint.getUserOpHash` = keccak256(abi.encode(hash(userOp), entryPoint, chainId)).
 *      Parámetros en `memory` (calldata se copia implícitamente al llamar).
 */
library UserOperationLib {
    uint256 internal constant PAYMASTER_VALIDATION_GAS_OFFSET = 20;
    uint256 internal constant PAYMASTER_POSTOP_GAS_OFFSET = 36;
    uint256 internal constant PAYMASTER_DATA_OFFSET = 52;

    /**
     * @notice Empaqueta dos `uint128` en un `bytes32` (high | low).
     * @param high Bits superiores (verificationGasLimit / maxPriorityFeePerGas).
     * @param low Bits inferiores (callGasLimit / maxFeePerGas).
     */
    function packUints(uint128 high, uint128 low) internal pure returns (bytes32 packed) {
        packed = bytes32((uint256(high) << 128) | uint256(low));
    }

    /**
     * @notice Empaqueta `verificationGasLimit` y `callGasLimit`.
     */
    function packAccountGasLimits(uint128 verificationGasLimit, uint128 callGasLimit)
        internal
        pure
        returns (bytes32)
    {
        return packUints(verificationGasLimit, callGasLimit);
    }

    /**
     * @notice Empaqueta `maxPriorityFeePerGas` y `maxFeePerGas`.
     */
    function packGasFees(uint128 maxPriorityFeePerGas, uint128 maxFeePerGas) internal pure returns (bytes32) {
        return packUints(maxPriorityFeePerGas, maxFeePerGas);
    }

    /**
     * @notice Desempaqueta high128 / low128 de un `bytes32`.
     */
    function unpackUints(bytes32 packed) internal pure returns (uint256 high128, uint256 low128) {
        return AAUserOperationLib.unpackUints(packed);
    }

    /**
     * @notice Arma `paymasterAndData` estático (52 bytes) + data opcional.
     * @param paymaster Dirección del paymaster.
     * @param verificationGasLimit Gas de `validatePaymasterUserOp`.
     * @param postOpGasLimit Gas de `postOp`.
     * @param data Bytes específicos del paymaster (pueden ser vacíos).
     */
    function packPaymasterAndData(
        address paymaster,
        uint128 verificationGasLimit,
        uint128 postOpGasLimit,
        bytes memory data
    ) internal pure returns (bytes memory paymasterAndData) {
        paymasterAndData = abi.encodePacked(paymaster, verificationGasLimit, postOpGasLimit, data);
    }

    /**
     * @notice Encode canónico (sin signature) — equivalente a AA `UserOperationLib.encode`.
     */
    function encode(PackedUserOperation memory userOp) internal pure returns (bytes memory) {
        return abi.encode(
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.initCode),
            keccak256(userOp.callData),
            userOp.accountGasLimits,
            userOp.preVerificationGas,
            userOp.gasFees,
            keccak256(userOp.paymasterAndData)
        );
    }

    /**
     * @notice Hash interno del UserOp (sin signature).
     */
    function hash(PackedUserOperation memory userOp) internal pure returns (bytes32) {
        return keccak256(encode(userOp));
    }

    /**
     * @notice Request id firmable: igual que `EntryPoint.getUserOpHash`.
     * @param userOp UserOp packed v0.7.
     * @param entryPoint Dirección del EntryPoint.
     * @param chainId Chain id del dominio.
     */
    function getUserOpHash(PackedUserOperation memory userOp, address entryPoint, uint256 chainId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(hash(userOp), entryPoint, chainId));
    }
}

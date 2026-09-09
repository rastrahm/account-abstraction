pragma solidity 0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {InvalidUserOpSignature, ZeroAddress} from "../errors/AccountAbstractionErrors.sol";
import {ValidationDataLib} from "../libraries/ValidationDataLib.sol";

/**
 * @title SignatureValidator
 * @notice Verificación ECDSA secp256k1 sobre `userOpHash` (ERC-4337).
 * @dev Usa el prefijo Ethereum Signed Message (`personal_sign` / eth_sign),
 *      alineado al sample `SimpleAccount` de eth-infinitism v0.7.
 */
library SignatureValidator {
    /**
     * @notice Recupera el signer a partir de `userOpHash` + signature.
     * @param userOpHash Hash canónico del EntryPoint (`getUserOpHash`).
     * @param signature Firma ECDSA de 65 bytes sobre el eth-signed hash.
     * @return signer Dirección recuperada.
     */
    function recoverSigner(bytes32 userOpHash, bytes memory signature) internal pure returns (address signer) {
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(ethSigned, signature);
        if (err != ECDSA.RecoverError.NoError || recovered == address(0)) {
            revert InvalidUserOpSignature();
        }
        return recovered;
    }

    /**
     * @notice Comprueba si la firma corresponde al `owner` (sin revert).
     * @param userOpHash Hash canónico del EntryPoint.
     * @param signature Firma ECDSA (idealmente 65 bytes).
     * @param owner Owner esperado de la cuenta.
     * @return True si recover == owner.
     */
    function isValidSignature(bytes32 userOpHash, bytes memory signature, address owner)
        internal
        pure
        returns (bool)
    {
        if (owner == address(0)) {
            return false;
        }
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(ethSigned, signature);
        if (err != ECDSA.RecoverError.NoError || recovered == address(0)) {
            return false;
        }
        return recovered == owner;
    }

    /**
     * @notice Exige firma válida del owner; si no, `InvalidUserOpSignature`.
     * @param userOpHash Hash canónico del EntryPoint.
     * @param signature Firma ECDSA.
     * @param owner Owner esperado (no puede ser cero).
     */
    function validateSignature(bytes32 userOpHash, bytes memory signature, address owner) internal pure {
        if (owner == address(0)) {
            revert ZeroAddress();
        }
        if (!isValidSignature(userOpHash, signature, owner)) {
            revert InvalidUserOpSignature();
        }
    }

    /**
     * @notice Convierte el resultado de firma a `validationData` ERC-4337.
     * @dev Éxito → `SIG_VALIDATION_SUCCESS` (0); fallo → `SIG_VALIDATION_FAILED` (1).
     *      No revierte ante firma inválida (apto para `validateUserOp` / simulación).
     * @param userOpHash Hash canónico del EntryPoint.
     * @param signature Firma ECDSA.
     * @param owner Owner esperado.
     * @return validationData Empaquetado mínimo (sin ventana temporal).
     */
    function toValidationData(bytes32 userOpHash, bytes memory signature, address owner)
        internal
        pure
        returns (uint256 validationData)
    {
        if (isValidSignature(userOpHash, signature, owner)) {
            return ValidationDataLib.SIG_VALIDATION_SUCCESS;
        }
        return ValidationDataLib.SIG_VALIDATION_FAILED;
    }
}

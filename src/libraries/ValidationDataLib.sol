pragma solidity 0.8.24;

/**
 * @title ValidationDataLib
 * @notice Pack / unpack de `validationData` (sigAuthorizer | validUntil | validAfter).
 * @dev Compatible con `Helpers.sol` de account-abstraction v0.7.
 */
library ValidationDataLib {
    /// @notice Firma inválida reportada sin revert (simulación).
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// @notice Firma válida / success.
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;

    /**
     * @notice Empaqueta validationData sin aggregator externo.
     * @param sigFailed True si la firma falló.
     * @param validUntil Último timestamp válido (0 = indefinite → max en parse).
     * @param validAfter Primer timestamp válido.
     */
    function pack(bool sigFailed, uint48 validUntil, uint48 validAfter) internal pure returns (uint256) {
        return (sigFailed ? SIG_VALIDATION_FAILED : SIG_VALIDATION_SUCCESS) | (uint256(validUntil) << 160)
            | (uint256(validAfter) << (160 + 48));
    }

    /**
     * @notice Desempaqueta validationData.
     * @dev `validUntil == 0` se interpreta como `type(uint48).max`.
     */
    function parse(uint256 validationData)
        internal
        pure
        returns (address aggregator, uint48 validAfter, uint48 validUntil)
    {
        aggregator = address(uint160(validationData));
        validUntil = uint48(validationData >> 160);
        if (validUntil == 0) {
            validUntil = type(uint48).max;
        }
        validAfter = uint48(validationData >> (160 + 48));
    }
}

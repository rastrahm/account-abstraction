pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar `forge build` / `forge test`.
 * @dev Se elimina en fases posteriores cuando existan contratos de negocio.
 */
contract Placeholder {
    /// @notice Identificador trivial del módulo.
    /// @return Nombre corto del módulo 12.
    function moduleName() external pure returns (string memory) {
        return "12-account-abstraction";
    }
}

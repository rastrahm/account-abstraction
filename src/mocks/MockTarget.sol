pragma solidity 0.8.24;

/**
 * @title MockTarget
 * @notice Contrato auxiliar para tests de `execute` / `executeBatch`.
 */
contract MockTarget {
    uint256 public value;
    address public lastCaller;

    error Boom();

    function setValue(uint256 newValue) external {
        value = newValue;
        lastCaller = msg.sender;
    }

    function fail() external pure {
        revert Boom();
    }

    receive() external payable {}
}

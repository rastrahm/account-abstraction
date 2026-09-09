pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke test de Fase 0: tooling Foundry operativo.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_moduleName() public view {
        assertEq(placeholder.moduleName(), "12-account-abstraction");
    }
}

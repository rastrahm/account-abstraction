pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ValidationDataLib} from "../src/libraries/ValidationDataLib.sol";
import {_packValidationData, _parseValidationData, ValidationData} from "account-abstraction/core/Helpers.sol";

/**
 * @title ValidationDataLibTest
 * @notice Pack/parse de validationData alineado a Helpers AA v0.7.
 */
contract ValidationDataLibTest is Test {
    function test_pack_success_matchesAA() public pure {
        uint48 validUntil = 1_700_000_000;
        uint48 validAfter = 1_600_000_000;

        uint256 ours = ValidationDataLib.pack(false, validUntil, validAfter);
        uint256 aa = _packValidationData(false, validUntil, validAfter);
        assertEq(ours, aa);
    }

    function test_pack_sigFailed_matchesAA() public pure {
        uint256 ours = ValidationDataLib.pack(true, 0, 0);
        uint256 aa = _packValidationData(true, 0, 0);
        assertEq(ours, aa);
        assertEq(ours & type(uint160).max, ValidationDataLib.SIG_VALIDATION_FAILED);
    }

    function test_parse_validUntilZeroBecomesMax() public pure {
        uint256 packed = ValidationDataLib.pack(false, 0, 123);
        (address aggregator, uint48 validAfter, uint48 validUntil) = ValidationDataLib.parse(packed);

        ValidationData memory aa = _parseValidationData(packed);
        assertEq(aggregator, address(0));
        assertEq(validAfter, 123);
        assertEq(validUntil, type(uint48).max);
        assertEq(aggregator, aa.aggregator);
        assertEq(validAfter, aa.validAfter);
        assertEq(validUntil, aa.validUntil);
    }

    function testFuzz_packParse_matchesAA(bool sigFailed, uint48 validUntil, uint48 validAfter) public pure {
        uint256 ours = ValidationDataLib.pack(sigFailed, validUntil, validAfter);
        assertEq(ours, _packValidationData(sigFailed, validUntil, validAfter));

        (address aggregator, uint48 after_, uint48 until_) = ValidationDataLib.parse(ours);
        ValidationData memory aa = _parseValidationData(ours);
        assertEq(aggregator, aa.aggregator);
        assertEq(after_, aa.validAfter);
        assertEq(until_, aa.validUntil);
    }
}

pragma solidity 0.8.24;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UserOpTestBase} from "../helpers/UserOpTestBase.sol";
import {MockTarget} from "../../src/mocks/MockTarget.sol";

/**
 * @title UserOpFuzzTest
 * @notice Fase 5: fuzz de targets/calldata vía handleOps y bounds de depósito paymaster.
 */
contract UserOpFuzzTest is UserOpTestBase {
    function setUp() public {
        _setUpUserOpStack();
    }

    function testFuzz_e2e_setValue(uint256 newValue) public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (newValue)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        _handleOps(userOp);
        assertEq(target.value(), newValue);
        assertEq(account.getNonce(), 1);
    }

    function testFuzz_e2e_transferValue(uint96 sendValue) public {
        sendValue = uint96(bound(sendValue, 0, 1 ether));
        uint256 accountBalBefore = address(account).balance;

        bytes memory callData = _executeCallData(address(target), sendValue, bytes(""));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        _handleOps(userOp);

        assertEq(address(target).balance, sendValue);
        assertEq(address(account).balance, accountBalBefore - sendValue);
    }

    function testFuzz_e2e_withPaymaster(uint256 newValue) public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (newValue)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));

        uint256 pmBefore = paymaster.getDeposit();
        _handleOps(userOp);

        assertEq(target.value(), newValue);
        assertLt(paymaster.getDeposit(), pmBefore);
    }

    function testFuzz_paymasterDepositBounds(bool fundEnough) public {
        uint256 current = paymaster.getDeposit();
        if (current > 0) {
            vm.prank(pmOwner);
            paymaster.withdrawTo(payable(pmOwner), current);
        }

        if (fundEnough) {
            vm.prank(pmOwner);
            paymaster.deposit{value: 5 ether}();
        } else {
            vm.prank(pmOwner);
            paymaster.deposit{value: 1 wei}();
        }

        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (7)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        if (!fundEnough) {
            vm.expectRevert();
            entryPoint.handleOps(ops, beneficiary);
            assertEq(target.value(), 0);
        } else {
            entryPoint.handleOps(ops, beneficiary);
            assertEq(target.value(), 7);
        }
    }

    function testFuzz_calldataTargets_onlyMockMutates(address randomTarget, uint256 newValue) public {
        vm.assume(randomTarget != address(target));
        vm.assume(randomTarget != address(account));
        vm.assume(randomTarget != address(entryPoint));
        vm.assume(randomTarget != address(paymaster));
        vm.assume(randomTarget.code.length == 0);

        // Call a EOA: no efecto en MockTarget; handleOps igual completa si call "succeeds".
        bytes memory callData =
            _executeCallData(randomTarget, 0, abi.encodeCall(MockTarget.setValue, (newValue)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        _handleOps(userOp);

        assertEq(target.value(), 0);
        assertEq(account.getNonce(), 1);
    }
}

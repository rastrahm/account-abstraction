pragma solidity 0.8.24;

import {IEntryPoint as AAEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UserOpTestBase} from "./helpers/UserOpTestBase.sol";
import {MockTarget} from "../src/mocks/MockTarget.sol";

/**
 * @title UserOpE2ETest
 * @notice Fase 5: ciclo completo UserOp → firma → EntryPoint → ejecución (± Paymaster).
 */
contract UserOpE2ETest is UserOpTestBase {
    function setUp() public {
        _setUpUserOpStack();
    }

    function test_e2e_withoutPaymaster_executesAndChargesAccount() public {
        uint256 accountDepositBefore = account.getDeposit();
        uint256 beneficiaryBefore = beneficiary.balance;

        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (42)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));

        _handleOps(userOp);

        assertEq(target.value(), 42);
        assertEq(target.lastCaller(), address(account));
        assertEq(account.getNonce(), 1);
        assertLt(account.getDeposit(), accountDepositBefore);
        assertGt(beneficiary.balance, beneficiaryBefore);
    }

    function test_e2e_withPaymaster_executesAndChargesPaymaster() public {
        uint256 pmDepositBefore = paymaster.getDeposit();
        uint256 accountDepositBefore = account.getDeposit();
        uint256 sponsoredBefore = paymaster.totalSponsoredGasCost();

        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (99)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));

        _handleOps(userOp);

        assertEq(target.value(), 99);
        assertEq(account.getNonce(), 1);
        assertLt(paymaster.getDeposit(), pmDepositBefore);
        assertEq(account.getDeposit(), accountDepositBefore);
        assertGt(paymaster.totalSponsoredGasCost(), sponsoredBefore);
    }

    function test_e2e_invalidSignature_revertsAA24() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _buildUserOp(callData, bytes(""));
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.signature = _sign(uint256(0xB0B), userOpHash);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.expectRevert(abi.encodeWithSelector(AAEntryPoint.FailedOp.selector, 0, "AA24 signature error"));
        entryPoint.handleOps(ops, beneficiary);
    }

    function test_e2e_replayNonce_revertsAA25() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        _handleOps(userOp);

        // Misma UserOp firmada con nonce 0 ya consumido.
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        vm.expectRevert(abi.encodeWithSelector(AAEntryPoint.FailedOp.selector, 0, "AA25 invalid account nonce"));
        entryPoint.handleOps(ops, beneficiary);
    }

    function test_e2e_executionRevert_emitsButOpSettles() public {
        bytes memory callData = _executeCallData(address(target), 0, abi.encodeCall(MockTarget.fail, ()));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));

        uint256 depositBefore = account.getDeposit();
        _handleOps(userOp);

        // Ejecución falla en el target; EntryPoint igual avanza nonce y cobra gas.
        assertEq(account.getNonce(), 1);
        assertLt(account.getDeposit(), depositBefore);
        assertEq(target.value(), 0);
    }

    function test_e2e_paymasterNotWhitelisted_revertsAA33() public {
        vm.prank(pmOwner);
        paymaster.setSponsored(address(account), false);

        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.expectPartialRevert(AAEntryPoint.FailedOpWithRevert.selector);
        entryPoint.handleOps(ops, beneficiary);
    }

    function test_e2e_paymasterDepositTooLow_reverts() public {
        // Vaciar depósito del paymaster dejando dust insuficiente para maxCost.
        uint256 deposit = paymaster.getDeposit();
        vm.prank(pmOwner);
        paymaster.withdrawTo(payable(pmOwner), deposit);

        vm.prank(pmOwner);
        paymaster.deposit{value: 1 wei}();

        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Puede ser AA31 (EP) o AA33 (nuestro revert por depósito).
        vm.expectRevert();
        entryPoint.handleOps(ops, beneficiary);
    }

    function test_e2e_withValue_transferViaAccount() public {
        uint256 sendValue = 0.25 ether;
        bytes memory callData = _executeCallData(address(target), sendValue, bytes(""));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));

        _handleOps(userOp);

        assertEq(address(target).balance, sendValue);
    }

    function test_e2e_secondUserOp_incrementsNonce() public {
        bytes memory callData1 =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        _handleOps(_signUserOp(_buildUserOp(callData1, bytes(""))));
        assertEq(account.getNonce(), 1);

        bytes memory callData2 =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (2)));
        _handleOps(_signUserOp(_buildUserOp(callData2, bytes(""))));
        assertEq(account.getNonce(), 2);
        assertEq(target.value(), 2);
    }
}

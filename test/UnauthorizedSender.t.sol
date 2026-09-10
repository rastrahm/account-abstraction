pragma solidity 0.8.24;

import {IPaymaster as ERC4337Paymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UserOpTestBase} from "./helpers/UserOpTestBase.sol";
import {MockTarget} from "../src/mocks/MockTarget.sol";
import {OnlyEntryPoint} from "../src/errors/AccountAbstractionErrors.sol";

/**
 * @title UnauthorizedSenderTest
 * @notice Fase 5: callers != EntryPoint no pueden validar ni ejecutar.
 */
contract UnauthorizedSenderTest is UserOpTestBase {
    function setUp() public {
        _setUpUserOpStack();
    }

    function test_attack_validateUserOp_fromEOA_reverts() public {
        PackedUserOperation memory userOp = _buildUserOp(
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1))), bytes("")
        );
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.validateUserOp(userOp, userOpHash, 0);
    }

    function test_attack_validateUserOp_fromOwner_reverts() public {
        PackedUserOperation memory userOp = _buildUserOp(
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1))), bytes("")
        );
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(owner);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.validateUserOp(userOp, userOpHash, 0);
    }

    function test_attack_execute_fromEOA_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.execute(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    function test_attack_execute_fromOwner_reverts() public {
        vm.prank(owner);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.execute(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    function test_attack_executeBatch_fromStranger_reverts() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](0);
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(MockTarget.setValue, (1));

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.executeBatch(targets, values, datas);
    }

    function test_attack_paymasterValidate_fromStranger_reverts() public {
        PackedUserOperation memory userOp =
            _buildUserOp(_executeCallData(address(target), 0, bytes("")), _pmAndData(0, 0));

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_attack_paymasterPostOp_fromStranger_reverts() public {
        bytes memory context = abi.encode(address(account), uint256(0.1 ether));

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        paymaster.postOp(ERC4337Paymaster.PostOpMode.opSucceeded, context, 0.01 ether, 1 gwei);
    }
}

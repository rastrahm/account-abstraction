pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {SmartAccount} from "../src/account/SmartAccount.sol";
import {MockTarget} from "../src/mocks/MockTarget.sol";
import {IEntryPoint} from "../src/interfaces/IEntryPoint.sol";
import {UserOperationLib} from "../src/libraries/UserOperationLib.sol";
import {ValidationDataLib} from "../src/libraries/ValidationDataLib.sol";
import {
    OnlyEntryPoint,
    ExecutionFailed,
    ZeroAddress,
    InvalidBatchLength
} from "../src/errors/AccountAbstractionErrors.sol";

/**
 * @title SmartAccountTest
 * @notice Suite Fase 3: EntryPoint-only auth, validateUserOp y execute.
 */
contract SmartAccountTest is Test {
    EntryPoint internal entryPoint;
    SmartAccount internal account;
    MockTarget internal target;

    uint256 internal ownerKey;
    address internal owner;
    address internal stranger;

    function setUp() public {
        ownerKey = 0xA11CE;
        owner = vm.addr(ownerKey);
        stranger = makeAddr("stranger");

        entryPoint = new EntryPoint();
        account = new SmartAccount(IEntryPoint(address(entryPoint)), owner);
        target = new MockTarget();

        vm.deal(address(account), 10 ether);
    }

    function test_constructor_setsImmutables() public view {
        assertEq(address(account.entryPoint()), address(entryPoint));
        assertEq(account.owner(), owner);
    }

    function test_constructor_zeroEntryPoint_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new SmartAccount(IEntryPoint(address(0)), owner);
    }

    function test_constructor_zeroOwner_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new SmartAccount(IEntryPoint(address(entryPoint)), address(0));
    }

    function test_validateUserOp_unauthorizedSender_reverts() public {
        PackedUserOperation memory userOp = _blankUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.validateUserOp(userOp, userOpHash, 0);
    }

    function test_execute_unauthorizedSender_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.execute(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    function test_execute_ownerDirect_reverts() public {
        vm.prank(owner);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.execute(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    function test_executeBatch_unauthorizedSender_reverts() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](0);
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(MockTarget.setValue, (1));

        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        account.executeBatch(targets, values, datas);
    }

    function test_validateUserOp_validSignature() public {
        PackedUserOperation memory userOp = _blankUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.signature = _sign(ownerKey, userOpHash);

        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, ValidationDataLib.SIG_VALIDATION_SUCCESS);
    }

    function test_validateUserOp_invalidSignature_returnsFailed() public {
        PackedUserOperation memory userOp = _blankUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.signature = _sign(uint256(0xB0B), userOpHash);

        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, ValidationDataLib.SIG_VALIDATION_FAILED);
    }

    function test_validateUserOp_paysMissingFunds() public {
        uint256 missing = 1 ether;
        uint256 epBefore = address(entryPoint).balance;

        PackedUserOperation memory userOp = _blankUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.signature = _sign(ownerKey, userOpHash);

        vm.prank(address(entryPoint));
        account.validateUserOp(userOp, userOpHash, missing);

        assertEq(address(entryPoint).balance, epBefore + missing);
    }

    function test_execute_success() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        vm.prank(address(entryPoint));
        account.execute(address(target), 0, data);

        assertEq(target.value(), 42);
        assertEq(target.lastCaller(), address(account));
    }

    function test_execute_withValue() public {
        vm.prank(address(entryPoint));
        account.execute(address(target), 0.5 ether, bytes(""));

        assertEq(address(target).balance, 0.5 ether);
    }

    function test_execute_failure_revertsExecutionFailed() public {
        bytes memory data = abi.encodeCall(MockTarget.fail, ());

        vm.prank(address(entryPoint));
        vm.expectRevert(ExecutionFailed.selector);
        account.execute(address(target), 0, data);
    }

    function test_executeBatch_success() public {
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);

        uint256[] memory values = new uint256[](0);

        bytes[] memory datas = new bytes[](2);
        datas[0] = abi.encodeCall(MockTarget.setValue, (1));
        datas[1] = abi.encodeCall(MockTarget.setValue, (7));

        vm.prank(address(entryPoint));
        account.executeBatch(targets, values, datas);

        assertEq(target.value(), 7);
    }

    function test_executeBatch_withValues() public {
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);

        uint256[] memory values = new uint256[](2);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;

        bytes[] memory datas = new bytes[](2);
        datas[0] = bytes("");
        datas[1] = bytes("");

        vm.prank(address(entryPoint));
        account.executeBatch(targets, values, datas);

        assertEq(address(target).balance, 0.3 ether);
    }

    function test_executeBatch_invalidLength_reverts() public {
        address[] memory targets = new address[](2);
        targets[0] = address(target);
        targets[1] = address(target);

        uint256[] memory values = new uint256[](0);
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(MockTarget.setValue, (1));

        vm.prank(address(entryPoint));
        vm.expectRevert(InvalidBatchLength.selector);
        account.executeBatch(targets, values, datas);
    }

    function test_addDeposit_and_getDeposit() public {
        account.addDeposit{value: 1 ether}();
        assertEq(account.getDeposit(), 1 ether);
    }

    function test_getNonce_startsAtZero() public view {
        assertEq(account.getNonce(), 0);
    }

    function test_userOpHash_matchesLib() public view {
        PackedUserOperation memory userOp = _blankUserOp();
        assertEq(
            entryPoint.getUserOpHash(userOp),
            UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid)
        );
    }

    function _blankUserOp() internal view returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(account),
            nonce: 0,
            initCode: bytes(""),
            callData: abi.encodeCall(SmartAccount.execute, (address(target), 0, abi.encodeCall(MockTarget.setValue, (1)))),
            accountGasLimits: UserOperationLib.packAccountGasLimits(100_000, 200_000),
            preVerificationGas: 50_000,
            gasFees: UserOperationLib.packGasFees(1 gwei, 20 gwei),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
    }

    function _sign(uint256 privateKey, bytes32 hash_) internal pure returns (bytes memory signature) {
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(hash_);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSigned);
        signature = abi.encodePacked(r, s, v);
    }
}

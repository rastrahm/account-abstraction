pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {SmartAccount} from "../../src/account/SmartAccount.sol";
import {SponsoringPaymaster} from "../../src/paymaster/SponsoringPaymaster.sol";
import {MockTarget} from "../../src/mocks/MockTarget.sol";
import {IEntryPoint} from "../../src/interfaces/IEntryPoint.sol";
import {UserOperationLib} from "../../src/libraries/UserOperationLib.sol";

/**
 * @title UserOpTestBase
 * @notice Utilidades compartidas para e2e / fuzz de UserOperations (Fase 5).
 */
abstract contract UserOpTestBase is Test {
    uint128 internal constant VERIFICATION_GAS = 500_000;
    uint128 internal constant CALL_GAS = 500_000;
    uint256 internal constant PRE_VERIFICATION_GAS = 50_000;
    uint128 internal constant MAX_PRIORITY_FEE = 1 gwei;
    uint128 internal constant MAX_FEE = 1 gwei;
    uint128 internal constant PM_VERIFICATION_GAS = 200_000;
    uint128 internal constant PM_POSTOP_GAS = 100_000;

    EntryPoint internal entryPoint;
    SmartAccount internal account;
    SponsoringPaymaster internal paymaster;
    MockTarget internal target;

    uint256 internal ownerKey;
    address internal owner;
    address payable internal beneficiary;
    address internal stranger;
    address internal pmOwner;

    function _setUpUserOpStack() internal {
        ownerKey = 0xA11CE;
        owner = vm.addr(ownerKey);
        stranger = makeAddr("stranger");
        pmOwner = makeAddr("pmOwner");
        beneficiary = payable(makeAddr("beneficiary"));

        entryPoint = new EntryPoint();
        account = new SmartAccount(IEntryPoint(address(entryPoint)), owner);
        target = new MockTarget();

        vm.prank(pmOwner);
        paymaster = new SponsoringPaymaster(IEntryPoint(address(entryPoint)));

        vm.prank(pmOwner);
        paymaster.setSponsored(address(account), true);

        vm.deal(address(account), 20 ether);
        vm.deal(pmOwner, 50 ether);
        vm.prank(pmOwner);
        paymaster.deposit{value: 20 ether}();

        account.addDeposit{value: 5 ether}();
    }

    function _sign(uint256 privateKey, bytes32 hash_) internal pure returns (bytes memory signature) {
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(hash_);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSigned);
        signature = abi.encodePacked(r, s, v);
    }

    function _executeCallData(address to, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodeCall(SmartAccount.execute, (to, value, data));
    }

    function _pmAndData(uint48 validUntil, uint48 validAfter) internal view returns (bytes memory) {
        return UserOperationLib.packPaymasterAndData(
            address(paymaster),
            PM_VERIFICATION_GAS,
            PM_POSTOP_GAS,
            abi.encodePacked(validUntil, validAfter)
        );
    }

    function _buildUserOp(bytes memory callData, bytes memory paymasterAndData)
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: address(account),
            nonce: entryPoint.getNonce(address(account), 0),
            initCode: bytes(""),
            callData: callData,
            accountGasLimits: UserOperationLib.packAccountGasLimits(VERIFICATION_GAS, CALL_GAS),
            preVerificationGas: PRE_VERIFICATION_GAS,
            gasFees: UserOperationLib.packGasFees(MAX_PRIORITY_FEE, MAX_FEE),
            paymasterAndData: paymasterAndData,
            signature: bytes("")
        });
    }

    function _signUserOp(PackedUserOperation memory userOp) internal view returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.signature = _sign(ownerKey, userOpHash);
        return userOp;
    }

    function _handleOps(PackedUserOperation memory userOp) internal {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        entryPoint.handleOps(ops, beneficiary);
    }
}

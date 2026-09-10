pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IPaymaster as ERC4337Paymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {SponsoringPaymaster} from "../src/paymaster/SponsoringPaymaster.sol";
import {IEntryPoint} from "../src/interfaces/IEntryPoint.sol";
import {UserOperationLib} from "../src/libraries/UserOperationLib.sol";
import {ValidationDataLib} from "../src/libraries/ValidationDataLib.sol";
import {OnlyEntryPoint, PaymasterValidationFailed, ZeroAddress} from "../src/errors/AccountAbstractionErrors.sol";

/**
 * @title SponsoringPaymasterTest
 * @notice Suite Fase 4: reglas de sponsorship, depósito, postOp y admin.
 */
contract SponsoringPaymasterTest is Test {
    EntryPoint internal entryPoint;
    SponsoringPaymaster internal paymaster;

    address internal owner;
    address internal stranger;
    address internal sponsoredAccount;
    address internal otherAccount;

    uint128 internal constant PM_VERIFICATION_GAS = 50_000;
    uint128 internal constant PM_POSTOP_GAS = 40_000;

    function setUp() public {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");
        sponsoredAccount = makeAddr("sponsored");
        otherAccount = makeAddr("other");

        entryPoint = new EntryPoint();

        vm.prank(owner);
        paymaster = new SponsoringPaymaster(IEntryPoint(address(entryPoint)));

        vm.prank(owner);
        paymaster.setSponsored(sponsoredAccount, true);

        vm.deal(owner, 100 ether);
        vm.prank(owner);
        paymaster.deposit{value: 10 ether}();
    }

    function test_constructor_zeroEntryPoint_reverts() public {
        vm.expectRevert(ZeroAddress.selector);
        new SponsoringPaymaster(IEntryPoint(address(0)));
    }

    function test_validate_unauthorizedSender_reverts() public {
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(type(uint48).max, 0));
        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_postOp_unauthorizedSender_reverts() public {
        bytes memory context = abi.encode(sponsoredAccount, uint256(0.1 ether));
        vm.prank(stranger);
        vm.expectRevert(OnlyEntryPoint.selector);
        paymaster.postOp(ERC4337Paymaster.PostOpMode.opSucceeded, context, 0.01 ether, 1 gwei);
    }

    function test_validate_happyPath() public {
        uint256 maxCost = 0.5 ether;
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(type(uint48).max, 0));

        vm.prank(address(entryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);

        (address sender, uint256 encodedMaxCost) = abi.decode(context, (address, uint256));
        assertEq(sender, sponsoredAccount);
        assertEq(encodedMaxCost, maxCost);
        assertEq(validationData, ValidationDataLib.pack(false, type(uint48).max, 0));
    }

    function test_validate_notWhitelisted_reverts() public {
        PackedUserOperation memory userOp = _userOp(otherAccount, _pmData(type(uint48).max, 0));

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_validate_insufficientDeposit_reverts() public {
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(type(uint48).max, 0));

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 50 ether);
    }

    function test_validate_maxCostPerOpExceeded_reverts() public {
        vm.prank(owner);
        paymaster.setMaxCostPerOp(0.2 ether);

        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(type(uint48).max, 0));

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.3 ether);
    }

    function test_validate_expired_reverts() public {
        vm.warp(1_700_000_100);
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(1_700_000_000, 0));

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_validate_tooEarly_reverts() public {
        vm.warp(1_000);
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, _pmData(type(uint48).max, 2_000));

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_validate_wrongPaymasterAddress_reverts() public {
        bytes memory data = UserOperationLib.packPaymasterAndData(
            address(0xBEEF), PM_VERIFICATION_GAS, PM_POSTOP_GAS, paymaster.encodeSponsorshipData(type(uint48).max, 0)
        );
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, data);

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_validate_shortPaymasterAndData_reverts() public {
        bytes memory data = UserOperationLib.packPaymasterAndData(
            address(paymaster), PM_VERIFICATION_GAS, PM_POSTOP_GAS, bytes("")
        );
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, data);

        vm.prank(address(entryPoint));
        vm.expectRevert(PaymasterValidationFailed.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.1 ether);
    }

    function test_postOp_accountsGas() public {
        bytes memory context = abi.encode(sponsoredAccount, uint256(1 ether));

        vm.expectEmit(true, false, false, true);
        emit SponsoringPaymaster.UserOpSponsored(
            sponsoredAccount, 0.05 ether, ERC4337Paymaster.PostOpMode.opSucceeded
        );

        vm.prank(address(entryPoint));
        paymaster.postOp(ERC4337Paymaster.PostOpMode.opSucceeded, context, 0.05 ether, 1 gwei);

        assertEq(paymaster.totalSponsoredGasCost(), 0.05 ether);
    }

    function test_postOp_opReverted_stillAccounts() public {
        bytes memory context = abi.encode(sponsoredAccount, uint256(1 ether));

        vm.prank(address(entryPoint));
        paymaster.postOp(ERC4337Paymaster.PostOpMode.opReverted, context, 0.02 ether, 1 gwei);

        assertEq(paymaster.totalSponsoredGasCost(), 0.02 ether);
    }

    function test_setSponsored_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert();
        paymaster.setSponsored(otherAccount, true);
    }

    function test_setSponsored_zeroAddress_reverts() public {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        paymaster.setSponsored(address(0), true);
    }

    function test_withdrawTo_onlyOwner() public {
        uint256 beforeBal = owner.balance;
        vm.prank(owner);
        paymaster.withdrawTo(payable(owner), 1 ether);
        assertEq(owner.balance, beforeBal + 1 ether);
        assertEq(paymaster.getDeposit(), 9 ether);
    }

    function test_withdrawTo_stranger_reverts() public {
        vm.prank(stranger);
        vm.expectRevert();
        paymaster.withdrawTo(payable(stranger), 1 ether);
    }

    function test_getDeposit() public view {
        assertEq(paymaster.getDeposit(), 10 ether);
    }

    function testFuzz_validate_respectsMaxCostPerOp(uint256 maxCost, uint256 limit) public {
        limit = bound(limit, 1 wei, 5 ether);
        maxCost = bound(maxCost, 1 wei, 5 ether);

        vm.prank(owner);
        paymaster.setMaxCostPerOp(limit);

        uint256 deposit = paymaster.getDeposit();
        bytes memory pmAndData = UserOperationLib.packPaymasterAndData(
            address(paymaster),
            PM_VERIFICATION_GAS,
            PM_POSTOP_GAS,
            abi.encodePacked(type(uint48).max, uint48(0))
        );
        PackedUserOperation memory userOp = _userOp(sponsoredAccount, pmAndData);

        vm.startPrank(address(entryPoint));
        if (maxCost > limit || maxCost > deposit) {
            vm.expectRevert(PaymasterValidationFailed.selector);
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
        } else {
            (bytes memory context,) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
            (, uint256 encoded) = abi.decode(context, (address, uint256));
            assertEq(encoded, maxCost);
        }
        vm.stopPrank();
    }

    function _pmData(uint48 validUntil, uint48 validAfter) internal view returns (bytes memory) {
        return UserOperationLib.packPaymasterAndData(
            address(paymaster),
            PM_VERIFICATION_GAS,
            PM_POSTOP_GAS,
            paymaster.encodeSponsorshipData(validUntil, validAfter)
        );
    }

    function _userOp(address sender, bytes memory paymasterAndData)
        internal
        pure
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: bytes(""),
            callData: hex"12",
            accountGasLimits: UserOperationLib.packAccountGasLimits(100_000, 200_000),
            preVerificationGas: 50_000,
            gasFees: UserOperationLib.packGasFees(1 gwei, 20 gwei),
            paymasterAndData: paymasterAndData,
            signature: bytes("")
        });
    }
}

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {SignatureValidator} from "../src/validation/SignatureValidator.sol";
import {InvalidUserOpSignature, ZeroAddress} from "../src/errors/AccountAbstractionErrors.sol";
import {ValidationDataLib} from "../src/libraries/ValidationDataLib.sol";
import {UserOperationLib} from "../src/libraries/UserOperationLib.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

/**
 * @title SignatureValidatorTest
 * @notice Suite Fase 2: ECDSA sobre `userOpHash` (válida / inválida / malformed).
 */
contract SignatureValidatorTest is Test {
    uint256 internal ownerKey;
    address internal owner;

    uint256 internal otherKey;
    address internal other;

    bytes32 internal userOpHash;

    function setUp() public {
        ownerKey = 0xA11CE;
        owner = vm.addr(ownerKey);
        otherKey = 0xB0B;
        other = vm.addr(otherKey);
        userOpHash = keccak256("module-12-userOpHash");
    }

    function test_isValidSignature_valid() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        assertTrue(SignatureValidator.isValidSignature(userOpHash, signature, owner));
    }

    function test_recoverSigner_matchesOwner() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        assertEq(SignatureValidator.recoverSigner(userOpHash, signature), owner);
    }

    function test_validateSignature_ok() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        SignatureValidator.validateSignature(userOpHash, signature, owner);
    }

    function test_toValidationData_success() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        assertEq(
            SignatureValidator.toValidationData(userOpHash, signature, owner),
            ValidationDataLib.SIG_VALIDATION_SUCCESS
        );
    }

    function test_isValidSignature_wrongSigner() public view {
        bytes memory signature = _sign(otherKey, userOpHash);
        assertFalse(SignatureValidator.isValidSignature(userOpHash, signature, owner));
    }

    function test_validateSignature_wrongSigner_reverts() public {
        bytes memory signature = _sign(otherKey, userOpHash);
        vm.expectRevert(InvalidUserOpSignature.selector);
        this.validateSignatureExternal(userOpHash, signature, owner);
    }

    function test_recoverSigner_wrongHash_revertsWhenComparedViaValidate() public {
        bytes memory signature = _sign(ownerKey, userOpHash);
        bytes32 otherHash = keccak256("other");
        vm.expectRevert(InvalidUserOpSignature.selector);
        this.validateSignatureExternal(otherHash, signature, owner);
    }

    function test_isValidSignature_wrongHash() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        assertFalse(SignatureValidator.isValidSignature(keccak256("other"), signature, owner));
    }

    function test_isValidSignature_malformedLength() public view {
        bytes memory bad = hex"deadbeef";
        assertFalse(SignatureValidator.isValidSignature(userOpHash, bad, owner));
    }

    function test_recoverSigner_malformed_reverts() public {
        bytes memory bad = hex"01";
        vm.expectRevert(InvalidUserOpSignature.selector);
        this.recoverSignerExternal(userOpHash, bad);
    }

    function test_isValidSignature_emptySignature() public view {
        assertFalse(SignatureValidator.isValidSignature(userOpHash, bytes(""), owner));
    }

    function test_isValidSignature_ownerZero() public view {
        bytes memory signature = _sign(ownerKey, userOpHash);
        assertFalse(SignatureValidator.isValidSignature(userOpHash, signature, address(0)));
    }

    function test_validateSignature_ownerZero_reverts() public {
        bytes memory signature = _sign(ownerKey, userOpHash);
        vm.expectRevert(ZeroAddress.selector);
        this.validateSignatureExternal(userOpHash, signature, address(0));
    }

    function test_toValidationData_failed() public view {
        bytes memory signature = _sign(otherKey, userOpHash);
        assertEq(
            SignatureValidator.toValidationData(userOpHash, signature, owner), ValidationDataLib.SIG_VALIDATION_FAILED
        );
    }

    function test_rawHashWithoutEthPrefix_isRejected() public view {
        // Firma sobre el hash crudo (sin personal_sign) no debe validar.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, userOpHash);
        bytes memory rawSig = abi.encodePacked(r, s, v);
        assertFalse(SignatureValidator.isValidSignature(userOpHash, rawSig, owner));
    }

    function test_endToEnd_userOpHashFromEntryPoint() public {
        EntryPoint entryPoint = new EntryPoint();
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: owner,
            nonce: 0,
            initCode: bytes(""),
            callData: hex"1234",
            accountGasLimits: UserOperationLib.packAccountGasLimits(100_000, 200_000),
            preVerificationGas: 21_000,
            gasFees: UserOperationLib.packGasFees(1 gwei, 20 gwei),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        bytes32 hashFromEp = entryPoint.getUserOpHash(userOp);
        bytes32 hashFromLib = UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid);
        assertEq(hashFromEp, hashFromLib);

        bytes memory signature = _sign(ownerKey, hashFromEp);
        userOp.signature = signature;

        assertTrue(SignatureValidator.isValidSignature(hashFromEp, userOp.signature, owner));
        SignatureValidator.validateSignature(hashFromEp, userOp.signature, owner);
    }

    function testFuzz_validSignature(bytes32 hashSeed, uint256 pk) public view {
        pk = bound(pk, 1, type(uint128).max);
        address signer = vm.addr(pk);
        bytes memory signature = _sign(pk, hashSeed);
        assertTrue(SignatureValidator.isValidSignature(hashSeed, signature, signer));
        assertEq(SignatureValidator.recoverSigner(hashSeed, signature), signer);
    }

    function testFuzz_wrongSignerRejected(bytes32 hashSeed, uint256 pkOwner, uint256 pkOther) public view {
        pkOwner = bound(pkOwner, 1, type(uint128).max);
        pkOther = bound(pkOther, 1, type(uint128).max);
        vm.assume(pkOwner != pkOther);

        address owner_ = vm.addr(pkOwner);
        bytes memory signature = _sign(pkOther, hashSeed);
        assertFalse(SignatureValidator.isValidSignature(hashSeed, signature, owner_));
    }

    /// @dev Wrappers externos para `expectRevert` con library pura.
    function recoverSignerExternal(bytes32 hash_, bytes calldata signature) external pure returns (address) {
        return SignatureValidator.recoverSigner(hash_, signature);
    }

    function validateSignatureExternal(bytes32 hash_, bytes calldata signature, address owner_) external pure {
        SignatureValidator.validateSignature(hash_, signature, owner_);
    }

    function _sign(uint256 privateKey, bytes32 hash_) internal pure returns (bytes memory signature) {
        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(hash_);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSigned);
        signature = abi.encodePacked(r, s, v);
    }
}

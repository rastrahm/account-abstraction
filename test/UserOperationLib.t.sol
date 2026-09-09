pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "../src/libraries/UserOperationLib.sol";
import {UserOperationDocs} from "../src/interfaces/UserOperation.sol";

/**
 * @title UserOperationLibTest
 * @notice Verifica pack/hash frente a `EntryPoint.getUserOpHash` (ERC-4337 v0.7).
 */
contract UserOperationLibTest is Test {
    EntryPoint internal entryPoint;

    address internal constant SENDER = address(0xA11CE);
    address internal constant PAYMASTER = address(0xB01);

    function setUp() public {
        entryPoint = new EntryPoint();
    }

    function test_specConstant() public pure {
        assertEq(
            keccak256(bytes(UserOperationDocs.SPEC)), keccak256(bytes("ERC-4337-v0.7-PackedUserOperation"))
        );
    }

    function test_packAccountGasLimits_roundTrip() public pure {
        bytes32 packed = UserOperationLib.packAccountGasLimits(100_000, 200_000);
        (uint256 verificationGasLimit, uint256 callGasLimit) = UserOperationLib.unpackUints(packed);
        assertEq(verificationGasLimit, 100_000);
        assertEq(callGasLimit, 200_000);
    }

    function test_packGasFees_roundTrip() public pure {
        bytes32 packed = UserOperationLib.packGasFees(1 gwei, 30 gwei);
        (uint256 maxPriorityFeePerGas, uint256 maxFeePerGas) = UserOperationLib.unpackUints(packed);
        assertEq(maxPriorityFeePerGas, 1 gwei);
        assertEq(maxFeePerGas, 30 gwei);
    }

    function test_packPaymasterAndData_layout() public pure {
        bytes memory data = hex"deadbeef";
        bytes memory packed = UserOperationLib.packPaymasterAndData(PAYMASTER, 50_000, 40_000, data);
        assertEq(packed.length, 52 + data.length);
        assertEq(_readAddress(packed, 0), PAYMASTER);
        assertEq(_readUint128(packed, 20), 50_000);
        assertEq(_readUint128(packed, 36), 40_000);
        assertEq(_readBytes4(packed, 52), bytes4(data));
    }

    function test_getUserOpHash_matchesEntryPoint() public view {
        PackedUserOperation memory userOp = _sampleUserOp(bytes(""), bytes(""));
        bytes32 expected = entryPoint.getUserOpHash(userOp);
        bytes32 actual = UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid);
        assertEq(actual, expected);
    }

    function test_getUserOpHash_matchesEntryPoint_withPaymasterAndCalldata() public view {
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", SENDER, 1 wei, hex"01");
        bytes memory pmData = UserOperationLib.packPaymasterAndData(PAYMASTER, 80_000, 60_000, hex"c0ffee");
        PackedUserOperation memory userOp = _sampleUserOp(callData, pmData);

        assertEq(
            UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid), entryPoint.getUserOpHash(userOp)
        );
    }

    function test_getUserOpHash_changesWithSender() public view {
        PackedUserOperation memory a = _sampleUserOp(bytes(""), bytes(""));
        PackedUserOperation memory b = _sampleUserOp(bytes(""), bytes(""));
        b.sender = address(0xBEEF);

        assertTrue(entryPoint.getUserOpHash(a) != entryPoint.getUserOpHash(b));
        assertEq(UserOperationLib.getUserOpHash(a, address(entryPoint), block.chainid), entryPoint.getUserOpHash(a));
        assertEq(UserOperationLib.getUserOpHash(b, address(entryPoint), block.chainid), entryPoint.getUserOpHash(b));
    }

    function test_getUserOpHash_signatureExcludedFromInnerHash() public view {
        PackedUserOperation memory a = _sampleUserOp(bytes(""), bytes(""));
        PackedUserOperation memory b = _sampleUserOp(bytes(""), bytes(""));
        a.signature = hex"01";
        b.signature = hex"02";

        // El hash firmable incluye solo hash(encode sin signature) + EP + chainId.
        assertEq(UserOperationLib.hash(a), UserOperationLib.hash(b));
        assertEq(entryPoint.getUserOpHash(a), entryPoint.getUserOpHash(b));
        assertEq(UserOperationLib.getUserOpHash(a, address(entryPoint), block.chainid), entryPoint.getUserOpHash(a));
    }

    function test_getUserOpHash_dependsOnEntryPointAndChainId() public view {
        PackedUserOperation memory userOp = _sampleUserOp(bytes(""), bytes(""));
        bytes32 epHash = UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid);
        bytes32 otherEp = UserOperationLib.getUserOpHash(userOp, address(0x1234), block.chainid);
        bytes32 otherChain = UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid + 1);

        assertTrue(epHash != otherEp);
        assertTrue(epHash != otherChain);
        assertEq(epHash, entryPoint.getUserOpHash(userOp));
    }

    function testFuzz_getUserOpHash_matchesEntryPoint(
        address sender,
        uint256 nonce,
        bytes calldata initCode,
        bytes calldata callData,
        uint128 verificationGasLimit,
        uint128 callGasLimit,
        uint256 preVerificationGas,
        uint128 maxPriorityFeePerGas,
        uint128 maxFeePerGas,
        bytes calldata paymasterAndData,
        bytes calldata signature
    ) public view {
        vm.assume(sender != address(0));

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: initCode,
            callData: callData,
            accountGasLimits: UserOperationLib.packAccountGasLimits(verificationGasLimit, callGasLimit),
            preVerificationGas: preVerificationGas,
            gasFees: UserOperationLib.packGasFees(maxPriorityFeePerGas, maxFeePerGas),
            paymasterAndData: paymasterAndData,
            signature: signature
        });

        assertEq(
            UserOperationLib.getUserOpHash(userOp, address(entryPoint), block.chainid), entryPoint.getUserOpHash(userOp)
        );
    }

    function _sampleUserOp(bytes memory callData, bytes memory paymasterAndData)
        internal
        pure
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: SENDER,
            nonce: 0,
            initCode: bytes(""),
            callData: callData,
            accountGasLimits: UserOperationLib.packAccountGasLimits(100_000, 200_000),
            preVerificationGas: 50_000,
            gasFees: UserOperationLib.packGasFees(1 gwei, 20 gwei),
            paymasterAndData: paymasterAndData,
            signature: hex"aabb"
        });
    }

    function _readAddress(bytes memory data, uint256 offset) private pure returns (address addr) {
        bytes20 word;
        assembly ("memory-safe") {
            word := mload(add(add(data, 0x20), offset))
        }
        addr = address(word);
    }

    function _readUint128(bytes memory data, uint256 offset) private pure returns (uint128 value) {
        bytes16 word;
        assembly ("memory-safe") {
            word := mload(add(add(data, 0x20), offset))
        }
        value = uint128(word);
    }

    function _readBytes4(bytes memory data, uint256 offset) private pure returns (bytes4 value) {
        bytes4 word;
        assembly ("memory-safe") {
            word := mload(add(add(data, 0x20), offset))
        }
        value = word;
    }
}

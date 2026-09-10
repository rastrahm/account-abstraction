pragma solidity 0.8.24;

import {UserOpTestBase} from "../helpers/UserOpTestBase.sol";
import {MockTarget} from "../../src/mocks/MockTarget.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

/**
 * @title UserOpGasTest
 * @notice Fase 6: overhead UserOp vs llamada ECDSA EOA directa (`forge test --gas-report` / snapshot).
 */
contract UserOpGasTest is UserOpTestBase {
    address internal eoa;

    function setUp() public {
        _setUpUserOpStack();
        eoa = makeAddr("eoa");
        vm.deal(eoa, 1 ether);
    }

    /// @notice Baseline: EOA llama `setValue` directamente (sin AA).
    function testGas_EOA_setValue() public {
        vm.prank(eoa);
        target.setValue(1);
    }

    /// @notice UserOp sin paymaster: cuenta paga gas vía depósito EP.
    function testGas_UserOp_setValue() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        _handleOps(userOp);
    }

    /// @notice UserOp con SponsoringPaymaster.
    function testGas_UserOp_withPaymaster_setValue() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));
        _handleOps(userOp);
    }

    /// @notice Solo validación de cuenta (prank EP) — componente del overhead.
    function testGas_validateUserOp_only() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, bytes("")));
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        vm.prank(address(entryPoint));
        account.validateUserOp(userOp, userOpHash, 0);
    }

    /// @notice Solo execute vía EntryPoint (sin validate/handleOps).
    function testGas_execute_only() public {
        vm.prank(address(entryPoint));
        account.execute(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    /// @notice Validación paymaster aislada.
    function testGas_validatePaymasterUserOp_only() public {
        bytes memory callData =
            _executeCallData(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
        PackedUserOperation memory userOp = _signUserOp(_buildUserOp(callData, _pmAndData(0, 0)));

        vm.prank(address(entryPoint));
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0.01 ether);
    }
}

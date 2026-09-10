pragma solidity 0.8.24;

import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {IAccount} from "../interfaces/IAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {
    OnlyEntryPoint,
    ExecutionFailed,
    ZeroAddress,
    InvalidBatchLength
} from "../errors/AccountAbstractionErrors.sol";
import {SignatureValidator} from "../validation/SignatureValidator.sol";

/**
 * @title SmartAccount
 * @notice Cuenta ERC-4337 v0.7: valida UserOps y ejecuta calls solo vía EntryPoint.
 * @dev Owner y EntryPoint son `immutable`. La firma inválida retorna `SIG_VALIDATION_FAILED`
 *      (no revierte) para permitir simulación del bundler.
 */
contract SmartAccount is IAccount {
    /// @notice EntryPoint autorizado (único caller de validación/ejecución).
    IEntryPoint public immutable entryPoint;

    /// @notice Owner ECDSA de la cuenta.
    address public immutable owner;

    /**
     * @notice Emitido al desplegar la cuenta.
     * @param entryPoint_ EntryPoint vinculado.
     * @param owner_ Owner ECDSA.
     */
    event SmartAccountCreated(IEntryPoint indexed entryPoint_, address indexed owner_);

    /**
     * @param entryPoint_ EntryPoint ERC-4337 (no cero).
     * @param owner_ Signer autorizado (no cero).
     */
    constructor(IEntryPoint entryPoint_, address owner_) {
        if (address(entryPoint_) == address(0) || owner_ == address(0)) {
            revert ZeroAddress();
        }
        entryPoint = entryPoint_;
        owner = owner_;
        emit SmartAccountCreated(entryPoint_, owner_);
    }

    /// @notice Permite recibir ETH (prefund / transfers).
    receive() external payable {}

    /**
     * @notice Nonce secuencial (key = 0) gestionado por el EntryPoint.
     * @return nonce Actual según `getNonce(address,uint192)`.
     */
    function getNonce() external view returns (uint256) {
        return entryPoint.getNonce(address(this), 0);
    }

    /**
     * @notice Depósito actual de esta cuenta en el EntryPoint.
     */
    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * @notice Deposita ETH en el EntryPoint a nombre de esta cuenta.
     */
    function addDeposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Retira depósito de esta cuenta en el EntryPoint (solo vía EntryPoint / UserOp).
     * @param withdrawAddress Destino del ETH.
     * @param amount Cantidad a retirar.
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) external {
        _requireFromEntryPoint();
        if (withdrawAddress == address(0)) {
            revert ZeroAddress();
        }
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * @notice Valida firma y paga prefund faltante (solo EntryPoint).
     * @param userOp UserOp packed v0.7.
     * @param userOpHash Hash canónico del EntryPoint.
     * @param missingAccountFunds Fondos a depositar en el EntryPoint (puede ser 0).
     * @return validationData 0 si firma OK; 1 si firma inválida.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        validationData = SignatureValidator.toValidationData(userOpHash, userOp.signature, owner);
        _payPrefund(missingAccountFunds);
    }

    /**
     * @notice Ejecuta una llamada arbitraria (solo EntryPoint).
     * @param target Destino.
     * @param value ETH a enviar.
     * @param data Calldata.
     */
    function execute(address target, uint256 value, bytes calldata data) external {
        _requireFromEntryPoint();
        _call(target, value, data);
    }

    /**
     * @notice Ejecuta una secuencia de llamadas (solo EntryPoint).
     * @dev Si `values.length == 0`, cada call usa `value = 0`.
     * @param targets Destinos.
     * @param values ETH por call (vacío = todos 0).
     * @param datas Calldata por call.
     */
    function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas) external {
        _requireFromEntryPoint();
        uint256 length = targets.length;
        if (length != datas.length || (values.length != 0 && values.length != length)) {
            revert InvalidBatchLength();
        }
        if (values.length == 0) {
            for (uint256 i = 0; i < length; ++i) {
                _call(targets[i], 0, datas[i]);
            }
        } else {
            for (uint256 i = 0; i < length; ++i) {
                _call(targets[i], values[i], datas[i]);
            }
        }
    }

    function _requireFromEntryPoint() internal view {
        if (msg.sender != address(entryPoint)) {
            revert OnlyEntryPoint();
        }
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            // El EntryPoint verifica el depósito; fallos aquí se ignoran (spec AA).
            (success);
        }
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success,) = target.call{value: value}(data);
        if (!success) {
            revert ExecutionFailed();
        }
    }
}

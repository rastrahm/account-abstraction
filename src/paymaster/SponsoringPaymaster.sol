pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IPaymaster as ERC4337Paymaster} from "account-abstraction/interfaces/IPaymaster.sol";

import {IPaymaster} from "../interfaces/IPaymaster.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {
    OnlyEntryPoint,
    PaymasterValidationFailed,
    ZeroAddress
} from "../errors/AccountAbstractionErrors.sol";
import {UserOperationLib} from "../libraries/UserOperationLib.sol";
import {ValidationDataLib} from "../libraries/ValidationDataLib.sol";

/**
 * @title SponsoringPaymaster
 * @notice Paymaster ERC-4337 v0.7: patrocina gas a senders whitelisteados.
 * @dev Reglas on-chain:
 *      - `paymasterAndData` apunta a este contrato
 *      - sender en whitelist
 *      - depósito EP >= `maxCost`
 *      - `maxCost` <= `maxCostPerOp` (si el límite > 0)
 *      - ventana `validAfter`/`validUntil` (bytes tras el header de 52)
 *      `postOp` contabiliza gas patrocinado.
 */
contract SponsoringPaymaster is IPaymaster, Ownable2Step {
    /// @notice Offsets del payload custom tras el header AA (52 bytes).
    uint256 private constant VALID_UNTIL_OFFSET = UserOperationLib.PAYMASTER_DATA_OFFSET;
    uint256 private constant VALID_AFTER_OFFSET = VALID_UNTIL_OFFSET + 6;
    uint256 private constant SPONSORSHIP_DATA_LENGTH = 12;

    /// @notice EntryPoint vinculado.
    IEntryPoint public immutable entryPoint;

    /// @notice Tope por UserOp (0 = sin tope extra; solo depósito).
    uint256 public maxCostPerOp;

    /// @notice Gas coste acumulado patrocinado (postOp).
    uint256 public totalSponsoredGasCost;

    /// @notice Cuentas autorizadas a recibir sponsorship.
    mapping(address => bool) public isSponsored;

    /**
     * @notice Cambio de whitelist.
     * @param account Cuenta (sender del UserOp).
     * @param allowed True si se patrocina.
     */
    event SponsoredAccountSet(address indexed account, bool allowed);

    /**
     * @notice Nuevo tope de coste por UserOp.
     * @param maxCostPerOp_ Nuevo límite (0 = ilimitado salvo depósito).
     */
    event MaxCostPerOpSet(uint256 maxCostPerOp_);

    /**
     * @notice Liquidación post-ejecución.
     * @param sender Cuenta patrocinada.
     * @param actualGasCost Coste de gas reportado por el EntryPoint.
     * @param mode Resultado de la UserOp.
     */
    event UserOpSponsored(
        address indexed sender, uint256 actualGasCost, ERC4337Paymaster.PostOpMode mode
    );

    /**
     * @param entryPoint_ EntryPoint ERC-4337 (no cero).
     */
    constructor(IEntryPoint entryPoint_) Ownable(msg.sender) {
        if (address(entryPoint_) == address(0)) {
            revert ZeroAddress();
        }
        entryPoint = entryPoint_;
    }

    /**
     * @notice Autoriza o revoca sponsorship para un sender.
     * @param account Dirección de la Smart Account.
     * @param allowed True para incluir en whitelist.
     */
    function setSponsored(address account, bool allowed) external onlyOwner {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        isSponsored[account] = allowed;
        emit SponsoredAccountSet(account, allowed);
    }

    /**
     * @notice Configura el tope de `maxCost` aceptado por UserOp.
     * @param maxCostPerOp_ Límite en wei (0 = sin tope).
     */
    function setMaxCostPerOp(uint256 maxCostPerOp_) external onlyOwner {
        maxCostPerOp = maxCostPerOp_;
        emit MaxCostPerOpSet(maxCostPerOp_);
    }

    /**
     * @notice Deposita ETH en el EntryPoint a nombre de este paymaster.
     */
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Retira depósito del EntryPoint (solo owner).
     * @param withdrawAddress Destino.
     * @param amount Cantidad.
     */
    function withdrawTo(address payable withdrawAddress, uint256 amount) external onlyOwner {
        if (withdrawAddress == address(0)) {
            revert ZeroAddress();
        }
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * @notice Añade stake en el EntryPoint (solo owner).
     * @param unstakeDelaySec Delay de unstake (solo puede aumentar).
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    /**
     * @notice Inicia unlock del stake (solo owner).
     */
    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    /**
     * @notice Retira stake ya desbloqueado (solo owner).
     * @param withdrawAddress Destino.
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        if (withdrawAddress == address(0)) {
            revert ZeroAddress();
        }
        entryPoint.withdrawStake(withdrawAddress);
    }

    /**
     * @notice Depósito actual en el EntryPoint.
     */
    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * @notice Valida sponsorship (solo EntryPoint).
     * @param userOp UserOp packed (debe incluir `paymasterAndData` válido).
     * @param maxCost Coste máximo estimado por el EntryPoint.
     * @return context Datos para `postOp` (sender, maxCost).
     * @return validationData Ventana temporal empaquetada.
     */
    function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32, /*userOpHash*/ uint256 maxCost)
        external
        returns (bytes memory context, uint256 validationData)
    {
        _requireFromEntryPoint();
        return _validateSponsorship(userOp, maxCost);
    }

    /**
     * @notice Contabiliza el gas patrocinado tras la ejecución (solo EntryPoint).
     * @param mode Resultado de la UserOp.
     * @param context Contexto de `validatePaymasterUserOp`.
     * @param actualGasCost Coste real de gas (sin este `postOp`).
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external {
        _requireFromEntryPoint();
        (address sender,) = abi.decode(context, (address, uint256));
        totalSponsoredGasCost += actualGasCost;
        emit UserOpSponsored(sender, actualGasCost, mode);
    }

    /**
     * @notice Empaqueta el payload custom (`validUntil` || `validAfter`).
     * @param validUntil Último timestamp válido (0 = indefinite en EP).
     * @param validAfter Primer timestamp válido.
     */
    function encodeSponsorshipData(uint48 validUntil, uint48 validAfter) external pure returns (bytes memory) {
        return abi.encodePacked(validUntil, validAfter);
    }

    function _validateSponsorship(PackedUserOperation calldata userOp, uint256 maxCost)
        internal
        view
        returns (bytes memory context, uint256 validationData)
    {
        bytes calldata paymasterAndData = userOp.paymasterAndData;
        if (paymasterAndData.length < UserOperationLib.PAYMASTER_DATA_OFFSET + SPONSORSHIP_DATA_LENGTH) {
            revert PaymasterValidationFailed();
        }

        address paymaster = address(bytes20(paymasterAndData[0:20]));
        if (paymaster != address(this)) {
            revert PaymasterValidationFailed();
        }

        address sender = userOp.sender;
        if (!isSponsored[sender]) {
            revert PaymasterValidationFailed();
        }

        if (maxCostPerOp != 0 && maxCost > maxCostPerOp) {
            revert PaymasterValidationFailed();
        }

        if (entryPoint.balanceOf(address(this)) < maxCost) {
            revert PaymasterValidationFailed();
        }

        uint48 validUntil = uint48(bytes6(paymasterAndData[VALID_UNTIL_OFFSET:VALID_AFTER_OFFSET]));
        uint48 validAfter = uint48(bytes6(paymasterAndData[VALID_AFTER_OFFSET:VALID_AFTER_OFFSET + 6]));

        if (validAfter != 0 && block.timestamp < validAfter) {
            revert PaymasterValidationFailed();
        }
        if (validUntil != 0 && block.timestamp > validUntil) {
            revert PaymasterValidationFailed();
        }

        context = abi.encode(sender, maxCost);
        validationData = ValidationDataLib.pack(false, validUntil, validAfter);
    }

    function _requireFromEntryPoint() internal view {
        if (msg.sender != address(entryPoint)) {
            revert OnlyEntryPoint();
        }
    }
}

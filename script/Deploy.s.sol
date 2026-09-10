pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";

import {SmartAccount} from "../src/account/SmartAccount.sol";
import {SponsoringPaymaster} from "../src/paymaster/SponsoringPaymaster.sol";
import {IEntryPoint} from "../src/interfaces/IEntryPoint.sol";

/**
 * @title Deploy
 * @notice Despliega EntryPoint (local), SmartAccount, SponsoringPaymaster y fondea depósitos.
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `ACCOUNT_OWNER` — owner ECDSA de la SmartAccount (default = deployer)
 * - `ENTRY_POINT` — si se setea, no despliega EntryPoint nuevo (mainnet/testnet)
 * - `ACCOUNT_DEPOSIT` — wei a depositar en la cuenta (default 1 ether)
 * - `PAYMASTER_DEPOSIT` — wei a depositar en el paymaster (default 5 ether)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        address accountOwner = vm.envOr("ACCOUNT_OWNER", deployer);
        uint256 accountDeposit = vm.envOr("ACCOUNT_DEPOSIT", uint256(1 ether));
        uint256 paymasterDeposit = vm.envOr("PAYMASTER_DEPOSIT", uint256(5 ether));

        vm.startBroadcast(pk);

        address entryPointAddr = vm.envOr("ENTRY_POINT", address(0));
        IEntryPoint entryPoint;
        if (entryPointAddr == address(0)) {
            entryPoint = IEntryPoint(address(new EntryPoint()));
        } else {
            entryPoint = IEntryPoint(entryPointAddr);
        }

        SmartAccount account = new SmartAccount(entryPoint, accountOwner);
        SponsoringPaymaster paymaster = new SponsoringPaymaster(entryPoint);

        paymaster.setSponsored(address(account), true);

        if (paymasterDeposit > 0) {
            paymaster.deposit{value: paymasterDeposit}();
        }
        if (accountDeposit > 0) {
            account.addDeposit{value: accountDeposit}();
        }

        vm.stopBroadcast();

        console2.log("=== Account Abstraction Deploy (ERC-4337 v0.7) ===");
        console2.log("Deployer", deployer);
        console2.log("EntryPoint", address(entryPoint));
        console2.log("SmartAccount", address(account));
        console2.log("Account owner", accountOwner);
        console2.log("SponsoringPaymaster", address(paymaster));
        console2.log("Paymaster owner", paymaster.owner());
        console2.log("Account deposit", accountDeposit);
        console2.log("Paymaster deposit", paymasterDeposit);
    }
}

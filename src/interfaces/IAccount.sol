pragma solidity 0.8.24;

import {IAccount as ERC4337Account} from "account-abstraction/interfaces/IAccount.sol";

/**
 * @title IAccount
 * @notice Cuenta smart contract ERC-4337 v0.7 (`validateUserOp`).
 * @dev Alias tipado sobre `eth-infinitism/account-abstraction@v0.7.0` para imports estables del módulo.
 */
interface IAccount is ERC4337Account {}

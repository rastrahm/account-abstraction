pragma solidity 0.8.24;

import {IEntryPoint as ERC4337EntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

/**
 * @title IEntryPoint
 * @notice EntryPoint ERC-4337 v0.7 (`handleOps`, `getUserOpHash`, nonces 2D, depósitos).
 * @dev Alias tipado sobre `eth-infinitism/account-abstraction@v0.7.0`.
 */
interface IEntryPoint is ERC4337EntryPoint {}

pragma solidity 0.8.24;

import {IPaymaster as ERC4337Paymaster} from "account-abstraction/interfaces/IPaymaster.sol";

/**
 * @title IPaymaster
 * @notice Paymaster ERC-4337 v0.7 (`validatePaymasterUserOp` + `postOp`).
 * @dev Alias tipado sobre `eth-infinitism/account-abstraction@v0.7.0`.
 */
interface IPaymaster is ERC4337Paymaster {}

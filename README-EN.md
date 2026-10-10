# Module 12 — Account Abstraction (ERC-4337)

[🇪🇸 Español](./README-ES.md) · 🇬🇧 English · [Index](./README.md)

Smart Contract Account, Signature Validator and Sponsoring Paymaster on **ERC-4337 v0.7**, built with Foundry and Solidity `0.8.24`.

**Status:** v1 complete (Phases 0–6) · **Tests:** `forge test` → **98 PASS** · **Spec:** eth-infinitism `account-abstraction@v0.7.0`

---

## What's included

| Component | Description |
|-----------|-------------|
| `SmartAccount` | `IAccount`: `validateUserOp` + `execute` / `executeBatch` only via the EntryPoint |
| `SignatureValidator` | ECDSA secp256k1 over `userOpHash` (`personal_sign` prefix) |
| `SponsoringPaymaster` | Whitelist, EP deposit, `validUntil`/`validAfter`, `maxCostPerOp`, `postOp` |
| Libs | `UserOperationLib` (hash ≡ EntryPoint), `ValidationDataLib` |

---

## Requirements

- [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`)
- Use the real binary: `export PATH="$HOME/.foundry/bin:$PATH"`  
  (the nvm/npm `forge` is **not** Foundry)

---

## Setup

```bash
cd 12-account-abstraction
export PATH="$HOME/.foundry/bin:$PATH"

# Dependencies (gitignored under lib/)
forge install foundry-rs/forge-std --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
forge install eth-infinitism/account-abstraction@v0.7.0 --no-git --shallow

forge build
forge test
```

---

## Useful commands

```bash
forge test                          # full suite (98 PASS)
forge test --match-contract UserOpE2ETest -vv
forge test --match-contract UserOpGasTest --gas-report
forge snapshot --match-contract UserOpGasTest

# Local deploy (Anvil)
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### Environment variables (deploy)

| Variable | Default | Usage |
|----------|---------|-------|
| `PRIVATE_KEY` | Anvil #0 | Deployer |
| `ACCOUNT_OWNER` | deployer | ECDSA owner of the account |
| `ENTRY_POINT` | (empty → deploy new) | Existing EntryPoint on the network |
| `ACCOUNT_DEPOSIT` | `1 ether` | Account deposit in the EP |
| `PAYMASTER_DEPOSIT` | `5 ether` | Paymaster deposit in the EP |

---

## Structure

```text
12-account-abstraction/
├── src/
│   ├── account/SmartAccount.sol
│   ├── paymaster/SponsoringPaymaster.sol
│   ├── validation/SignatureValidator.sol
│   ├── libraries/{UserOperationLib,ValidationDataLib}.sol
│   ├── interfaces/…
│   ├── errors/AccountAbstractionErrors.sol
│   └── mocks/MockTarget.sol
├── test/
│   ├── UserOpE2E.t.sol
│   ├── UnauthorizedSender.t.sol
│   ├── fuzz/UserOp.fuzz.t.sol
│   ├── gas/UserOp.gas.t.sol
│   └── helpers/UserOpTestBase.sol
├── script/Deploy.s.sol
└── doc/                    ← planning, diagrams, SWC, gas
```

---

## Quick flow (UserOp)

1. Build a `PackedUserOperation` (sender = `SmartAccount`, EP nonce, `callData` = `execute(...)`).
2. Sign `EntryPoint.getUserOpHash(userOp)` with the owner (`personal_sign`).
3. Optional: `paymasterAndData` = paymaster + gas limits + `validUntil||validAfter`.
4. `entryPoint.handleOps([userOp], beneficiary)`.

On-chain auth: only the EntryPoint may call `validateUserOp` / `execute` / `validatePaymasterUserOp` / `postOp`.

---

## Gas (Phase 6 baseline)

| Path | Gas (snapshot) |
|------|----------------|
| EOA `setValue` | ~54 582 |
| UserOp (no PM) | ~159 870 (~2.9×) |
| UserOp + Paymaster | ~199 504 (~3.7×) |

Details: [`doc/GAS-EN.md`](./doc/GAS-EN.md)

---

## Security

SWC-100–136 audit: **0 vulnerabilities** within v1 scope.  
See [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md).

Custom errors: `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, `ZeroAddress`, `InvalidBatchLength`.

---

## Documentation

Full index: [`doc/README-EN.md`](./doc/README-EN.md)

**Portfolio page (ES/EN):** [`portfolio/index.html`](./portfolio/index.html)

| Doc | Contents |
|-----|----------|
| [planificacion-EN.md](./doc/planificacion-EN.md) | Phases 0–6, gates, criteria |
| [DECISIONES-Y-LOGICA-EN.md](./doc/DECISIONES-Y-LOGICA-EN.md) | Technical decisions, flow, gas improvements |
| [diagrama-de-clases-EN.md](./doc/diagrama-de-clases-EN.md) | Mermaid UML |
| [diagrama-de-flujo-EN.md](./doc/diagrama-de-flujo-EN.md) | Validate / PM / execute decisions |
| [flujograma-EN.md](./doc/flujograma-EN.md) | End-to-end actor cycle |
| [SWC-AUDIT-EN.md](./doc/SWC-AUDIT-EN.md) | SWC matrix |
| [GAS-EN.md](./doc/GAS-EN.md) | Benchmarks and optimizations |
| [SOCIAL-EN.md](./doc/SOCIAL-EN.md) | LinkedIn / X drafts |

---

## Stack

- Solidity `0.8.24` · Foundry · Cancun
- OpenZeppelin Contracts **v5.2.0**
- account-abstraction **v0.7.0** (`PackedUserOperation`)

# SWC Audit — Account Abstraction (ERC-4337)

[🇪🇸 Español](./SWC-AUDIT-ES.md) · 🇬🇧 English

Verification of the Smart Account, Signature Validator and Sponsoring Paymaster against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (custom errors, fixed pragma, EntryPoint-only auth, ECDSA).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/) and the [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) security considerations.

**Audited contracts (prod / core):**  
`src/account/SmartAccount.sol`, `src/paymaster/SponsoringPaymaster.sol`,  
`src/validation/SignatureValidator.sol`,  
`src/libraries/UserOperationLib.sol`, `src/libraries/ValidationDataLib.sol`,  
`src/interfaces/*`, `src/errors/AccountAbstractionErrors.sol`

**Trusted dependencies (out of scope for own bugs):**  
`lib/account-abstraction` EntryPoint v0.7, OpenZeppelin ECDSA / Ownable2Step

**Mocks (not prod):** `src/mocks/*`  
**Date:** 2026-09-10  
**Test references:** `test/SmartAccount.t.sol`, `test/SponsoringPaymaster.t.sol`, `test/SignatureValidator.t.sol`,  
`test/UserOpE2E.t.sol`, `test/UnauthorizedSender.t.sol`, `test/fuzz/`, `test/gas/`  
**Style:** aligned with [`11-upgradeable-proxies/doc/SWC-AUDIT-EN.md`](../../11-upgradeable-proxies/doc/SWC-AUDIT-EN.md)  
**Docs index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 30 |
| ⚠️ Informational (design / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within v1 scope (Account + Paymaster + SignatureValidator on EntryPoint v0.7). The module **restricts validation/execution to `msg.sender == entryPoint`**, verifies ECDSA with OZ (anti-malleability), and the paymaster requires whitelist + deposit + time window. Informational risks: centralized owner/paymaster-owner, use of `block.timestamp` in paymaster validation (in addition to `validationData`), and reliance on a correct canonical EntryPoint at deploy.

**Suite / module 12 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `AccountAbstractionErrors` |
| Fixed pragma `0.8.24` | ✅ |
| `msg.sender == entryPoint` in validate/execute/postOp | ✅ + unauthorized suite |
| ECDSA over `userOpHash` + eth-signed prefix | ✅ OZ `tryRecover` |
| 2D nonce via EntryPoint | ✅ e2e AA25 |
| Paymaster deposit / rules / timestamps | ✅ unit + e2e |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Unauthorized attack suite | ✅ `test/UnauthorizedSender.t.sol` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in Account Abstraction |
|----|-------|---------|--------|---------------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; checked `totalSponsoredGasCost +=` |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `execute` / batch check `success` → `ExecutionFailed`; `_payPrefund` ignores failure on purpose (AA spec) |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | No free withdraw; `withdrawDepositTo` / `withdrawTo` EP-only or `onlyOwner` |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Partial | ✅ | `execute` callable only by the EntryPoint (no anonymous reentrancy); EP uses `ReentrancyGuard`; CEI in paymaster admin |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `private` / `immutable` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` in module contracts |
| SWC-113 | DoS with Failed Call | Yes | ✅ | Failed call → `ExecutionFailed`; EP can still settle gas (e2e) |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Bundler / mempool UserOp ordering; see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `msg.sender` (== EntryPoint / OZ owner) |
| SWC-116 | Block values as a proxy for time | Yes | ⚠️ | Paymaster reads `block.timestamp` + packs `validUntil`/`validAfter` |
| SWC-117 | Signature Malleability | Yes | ✅ | OZ ECDSA rejects high `s` / invalid length |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing in core |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | Yes | ✅ | `userOpHash` includes EP+chainId; EntryPoint 2D nonce (AA25 e2e) |
| SWC-122 | Lack of Proper Signature Verification | Yes | ✅ | Recover + compare `owner`; soft-fail `SIG_VALIDATION_FAILED` |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit/e2e/fuzz/unauthorized |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No arbitrary-storage assembly in core |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IPaymaster` + `Ownable2Step`; Account implements `IAccount` |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | UserOp with low gas limits may fail validation; bounded by bundler / signers |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Long `executeBatch` may OOG (ops / bundler) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in core |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | Account ETH only leaves via `execute` (EP); EP deposits kept separate |
| SWC-133 | Hash Collisions (var-length args) | Partial | ✅ | Canonical AA UserOp hash (`encode` with `keccak256` of dynamic bytes) |
| SWC-134 | Message call with hardcoded gas | Partial | ⚠️ | `_payPrefund` uses `gas: type(uint256).max` (AA BaseAccount pattern) |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Storage / events public by design |

---

## Informational risks

### SWC-116 — `block.timestamp` in the paymaster

ERC-4337 recommends **not** relying on `block.timestamp` inside `validate*` and instead returning `validUntil`/`validAfter` in `validationData` so the EntryPoint enforces it. This module:

1. Packs the window into `validationData` (the EntryPoint enforces it).
2. **Additionally** reverts with `PaymasterValidationFailed` if the current time is outside it (business rule from the plan).

Risk: divergence between bundler simulation and inclusion if the clock crosses the boundary between simulation and mining. Operational mitigation: margins on `validUntil` / `validAfter`.

### SWC-114 — Ordering / bundling

UserOps compete in bundler mempools. Front-running of business intent is an AA domain risk, not a signature bypass. Mitigation: private relays / bundler policies (outside v1).

### SWC-134 — `gas: type(uint256).max` in prefund

Aligned with eth-infinitism `BaseAccount._payPrefund`. The EntryPoint verifies that the deposit was covered; a failed `call` is ignored on purpose.

### Centralization / post-deploy trust

| Topic | Risk | v1 treatment |
|-------|------|--------------|
| Immutable `SmartAccount.owner` | Key loss = unusable account | Document; recovery/factory (future) |
| `SponsoringPaymaster.owner` | Unilateral whitelist / withdraw | `Ownable2Step` |
| Wrong EntryPoint in constructor | Permanently misdirected auth | Deploy script + canonical address verification |
| Paymaster whitelist | Sponsoring a malicious account if the owner errs | Ops / multisig owner |

### SWC-126 / SWC-128 — gas limits and batches

Insufficient `verificationGasLimit` / `callGasLimit` → FailedOp. Huge batches → OOG. Responsibility of the UserOp builder / bundler.

---

## Monorepo principles checklist (+ module 12)

| Principle | Complies? | Notes |
|-----------|-----------|-------|
| Custom errors | ✅ | `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, … |
| EntryPoint-only validate/execute | ✅ | Unauthorized suite |
| ECDSA `userOpHash` | ✅ | + eth-signed message |
| Nonce via EP 2D | ✅ | |
| Paymaster deposit + rules | ✅ | |
| NatSpec public/external | ✅ | Core + libs |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/UserOp.fuzz.t.sol` |
| Attack suite | ✅ | `test/UnauthorizedSender.t.sol` |
| No floating pragma | ✅ | `0.8.24` |
| No ETH `transfer`/`send` | ✅ | Only `.call{value}` |
| Gas profiling UserOp vs EOA | ✅ | `doc/GAS-EN.md` |

---

## Verification findings (code)

### Confirmed mitigations

1. **SmartAccount:** `immutable` EP/owner; `validateUserOp` / `execute` / `executeBatch` / `withdrawDepositTo` → `OnlyEntryPoint`; signature soft-fail; `ExecutionFailed` / `InvalidBatchLength`.
2. **SignatureValidator:** OZ `tryRecover` + `MessageHashUtils`; malleability rejected; `InvalidUserOpSignature`.
3. **SponsoringPaymaster:** whitelist, `maxCostPerOp`, EP deposit, time window, `paymasterAndData` header; `Ownable2Step` admin; validate/postOp EP only.
4. **UserOperationLib:** `getUserOpHash` ≡ `EntryPoint.getUserOpHash` (fuzz 1000).
5. **E2E:** handleOps with/without PM, AA24/AA25, deposit charging.

### Phase 6 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | `withdrawDepositTo` (EP only) | SWC-105 — deposit withdrawal without an unauthenticated path |
| 2 | `script/Deploy.s.sol` | Reproducible deploy + funding |
| 3 | `test/gas/UserOp.gas.t.sol` + `.gas-snapshot` | Overhead vs EOA |
| 4 | `doc/SWC-AUDIT-EN.md` / `doc/GAS-EN.md` | SWC-100–136 matrix + benchmarks |

### Non-blocking observations (v2)

| # | Observation | Severity | Suggested action |
|---|-------------|----------|------------------|
| 1 | Account owner not rotatable | Info | Account factory + guardians |
| 2 | Paymaster without off-chain sponsorship signature | Info | VerifyingPaymaster style (optional) |
| 3 | Timelock / multisig on PM owner | Info | Governance |
| 4 | Formal Foundry invariants | Improvement | handleOps handler |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | fuzz + `totalSponsoredGasCost` paths |
| SWC-103 | `forge build` fixed pragma |
| SWC-104 | `SmartAccount` `ExecutionFailed` |
| SWC-105 | `UnauthorizedSender` withdraw + PM `onlyOwner` |
| SWC-107 | Unauthorized + e2e (only EP executes) |
| SWC-116 | `SponsoringPaymaster` expired/tooEarly |
| SWC-117 / 122 | `SignatureValidator.t.sol` |
| SWC-121 | `UserOpE2E` replay AA25 |
| SWC-123 | unit + e2e + fuzz + unauthorized |
| Auth | `test/UnauthorizedSender.t.sol` |
| Hash | `UserOperationLib.t.sol` vs EntryPoint |

---

## Execution result

```text
forge test --summary
# 2026-09-10 Phase 6
UserOperationLibTest          10 PASS (+ fuzz 1000)
ValidationDataLibTest          4 PASS (+ fuzz 1000)
SignatureValidatorTest        18 PASS (+ fuzz 1000)
SmartAccountTest              19 PASS
SponsoringPaymasterTest       19 PASS (+ fuzz 1000)
UserOpE2ETest                  9 PASS
UnauthorizedSenderTest         8 PASS
UserOpFuzzTest                 5 PASS (1000 runs each)
UserOpGasTest                  6 PASS
Total: 98 PASS / 0 FAIL / 0 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337)
- [eth-infinitism/account-abstraction v0.7](https://github.com/eth-infinitism/account-abstraction)
- Module 11: [`11-upgradeable-proxies/doc/SWC-AUDIT-EN.md`](../../11-upgradeable-proxies/doc/SWC-AUDIT-EN.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)

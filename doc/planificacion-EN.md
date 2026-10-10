# Planning — Module 12: Account Abstraction (ERC-4337)

[🇪🇸 Español](./planificacion-ES.md) · 🇬🇧 English

**Status:** Phases **0–6** ✅ completed. Module closed at v1 planning level.  
**Progress rule:** each phase requires **explicit authorization** from the owner before starting.

---

## 1. Goal

Build a production-grade ERC-4337 stack with:

- **Smart Contract Account** compliant with `IAccount` (`validateUserOp` + execution).
- Custom **Paymaster** (`IPaymaster`) for gas sponsorship with expiration/sponsorship rules.
- ECDSA **Signature Validator** over secp256k1 via `userOpHash`.
- Strict **EntryPoint** integration (`msg.sender == entryPoint`).
- Stack: **Foundry + Solidity `0.8.24`** (fixed pragma), low-level calldata unpacking where it adds gas savings/clarity.

---

## 2. Scope

| Included | Excluded (v1) |
|----------|---------------|
| Account, Paymaster, Signature Validator, ERC-4337 interfaces, e2e/fuzz/gas tests | Signature aggregator / complex session keys |
| `userOpHash` + ECDSA validation | Passkeys / WebAuthn / social recovery |
| Paymaster deposit in EntryPoint + sponsorship rules | Production off-chain bundler |
| 2D nonce via EntryPoint (`getNonce(address,uint192)`) | Frontend (optional later phase) |
| Module custom errors | Advanced multi-clone account factory (optional post-v1) |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite`)

- **Exact** Solidity `0.8.24`.
- OpenZeppelin Contracts v5.x for ECDSA / audited utilities where they add value.
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports.
- Custom errors (no `require` with strings).
- CEI / access control on administrative functions.
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Module 12 (ERC-4337)

- Pinned spec: **ERC-4337 v0.7** (`PackedUserOperation`, eth-infinitism `account-abstraction@v0.7.0`).
- Module interfaces: `IAccount`, `IPaymaster`, `IEntryPoint` (typed aliases over AA).
- Authorization: `msg.sender == address(entryPoint)` in `validateUserOp`, `execute`/`executeBatch`, `withdrawDepositTo`, `validatePaymasterUserOp` and `postOp`.
- Signature: ECDSA secp256k1 over `userOpHash` + eth-signed prefix; soft-fail → `SIG_VALIDATION_FAILED`.
- Paymaster: EP deposit + whitelist + `maxCostPerOp` + `validUntil`/`validAfter`; failure → `PaymasterValidationFailed`.
- Nonces: EntryPoint 2D (`getNonce(address,uint192)`).
- Failed execution → `ExecutionFailed`; non-EntryPoint caller → `OnlyEntryPoint`.

---

## 4. Architecture (final v1)

```
12-account-abstraction/
├── README.md                         # bilingual index
├── README-ES.md / README-EN.md
├── doc/
│   ├── README.md                     # bilingual documentation index
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── DECISIONES-Y-LOGICA-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   ├── GAS-{ES,EN}.md
│   └── SOCIAL-{ES,EN}.md
├── src/
│   ├── account/SmartAccount.sol
│   ├── paymaster/SponsoringPaymaster.sol
│   ├── validation/SignatureValidator.sol
│   ├── libraries/
│   │   ├── UserOperationLib.sol
│   │   └── ValidationDataLib.sol
│   ├── interfaces/
│   │   ├── IAccount.sol
│   │   ├── IPaymaster.sol
│   │   ├── IEntryPoint.sol
│   │   └── UserOperation.sol
│   ├── errors/AccountAbstractionErrors.sol
│   └── mocks/MockTarget.sol
├── test/
│   ├── helpers/UserOpTestBase.sol
│   ├── UserOperationLib.t.sol
│   ├── ValidationDataLib.t.sol
│   ├── SignatureValidator.t.sol
│   ├── SmartAccount.t.sol
│   ├── SponsoringPaymaster.t.sol
│   ├── UserOpE2E.t.sol
│   ├── UnauthorizedSender.t.sol
│   ├── fuzz/UserOp.fuzz.t.sol
│   └── gas/UserOp.gas.t.sol
├── script/Deploy.s.sol
├── foundry.toml
├── remappings.txt
└── .gas-snapshot
```

### Contracts and responsibilities

| Contract / artifact | Responsibility |
|---------------------|----------------|
| `SmartAccount` | Validates UserOp (signature); executes calls; EP deposits; EntryPoint only |
| `SignatureValidator` | ECDSA recover / validate / `toValidationData` |
| `SponsoringPaymaster` | Whitelist + deposit + time window; accounting `postOp` |
| `UserOperationLib` | Pack gas/paymaster; `getUserOpHash` ≡ EntryPoint |
| `ValidationDataLib` | Pack/parse `validationData` (AA Helpers) |
| `EntryPoint` (dep) | `handleOps`, 2D nonces, gas charging |

---

## 5. Custom errors (mandatory for the module)

```solidity
error OnlyEntryPoint();
error ExecutionFailed();
error InvalidUserOpSignature();
error PaymasterValidationFailed();
error ZeroAddress();
error InvalidBatchLength();
```

Extend only if needed, always as custom errors.

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until you explicitly say: *"I authorize Phase N"* (or equivalent). |
| **Delivery** | When closing a phase: acceptance checklist + summary of touched files. |
| **Block** | If new scope appears, it is documented and new authorization is awaited. |
| **TDD** | Within each contract phase: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry setup + structure + ERC-4337 deps | ✅ Completed | ✅ Authorized |
| 1 | Interfaces + `UserOperation` + hash libs | ✅ Completed | ✅ Authorized |
| 2 | `SignatureValidator` + ECDSA owner | ✅ Completed | ✅ Authorized |
| 3 | `SmartAccount` (`validateUserOp` + execute) | ✅ Completed | ✅ Authorized |
| 4 | `SponsoringPaymaster` (validate + postOp + deposit) | ✅ Completed | ✅ Authorized |
| 5 | e2e suite + unauthorized sender + fuzz | ✅ Completed | ✅ Authorized |
| 6 | Gas profiling + Deploy + NatSpec / SWC hardening | ✅ Completed | ✅ Authorized |

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Goal:** compilable repo with tooling and pinned ERC-4337 dependencies.

1. `forge init` (or minimal structure compatible with the suite).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000.
3. Dependencies: `forge-std`, OpenZeppelin v5, and EntryPoint / account-abstraction (v0.6 or v0.7 version documented).
4. Folders `src/{account,paymaster,validation,interfaces,libraries}`, `test/`, `test/fuzz`, `test/gas`, `script/`, `doc/`.

**Exit criterion:** `forge build` OK; chosen ERC-4337 version written in this section.

**Done (2026-09-09):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer, fuzz `runs = 1000`) + `remappings.txt`.
- Dependencies in `lib/` (gitignored): `forge-std`, OpenZeppelin **v5.2.0**, `eth-infinitism/account-abstraction` **v0.7.0** (`PackedUserOperation`, `EntryPoint`, `IAccount`, `IPaymaster`).
- Pinned spec: **ERC-4337 v0.7** (not v0.6).
- Folders `src/{account,paymaster,validation,interfaces,libraries,errors}`, `test/{fuzz,gas}`, `script/`.
- Stub `src/Placeholder.sol` + smoke `test/Placeholder.t.sol`.
- Remappings verified (`account-abstraction/interfaces/...`).
- `forge build` and `forge test` green (**1 PASS**).

---

### Phase 1 — Interfaces + UserOperation + hash ✅

**Goal:** stable types and interfaces for the rest of the module.

1. Define / adapt `UserOperation` (or `PackedUserOperation` if v0.7).
2. `IAccount`, `IPaymaster`, `IEntryPoint` interfaces aligned with the chosen spec.
3. UserOp hash library (EntryPoint compatible).
4. Unit tests for hash / packing if there is custom logic.

**Exit criterion:** clean compilation; UserOp hash verifiable against the EntryPoint reference.

**Done (2026-09-09):**
- Module interfaces: `IAccount`, `IPaymaster`, `IEntryPoint` (inherit eth-infinitism v0.7).
- Docs `UserOperation.sol` + `UserOperationDocs.SPEC` = `ERC-4337-v0.7-PackedUserOperation`.
- `UserOperationLib`: pack gas/paymaster, `encode`/`hash`/`getUserOpHash` ≡ `EntryPoint.getUserOpHash`.
- `ValidationDataLib`: pack/parse ≡ AA `Helpers.sol`.
- `AccountAbstractionErrors` (module custom errors).
- Tests: `UserOperationLib.t.sol` + `ValidationDataLib.t.sol` (includes fuzz 1000 vs real EntryPoint).
- `Placeholder` stub removed.
- **14 PASS** (`forge test`).

---

### Phase 2 — SignatureValidator ✅

**Goal:** efficient ECDSA verification over `userOpHash`.

1. Tests: valid signature → OK; invalid signature / wrong signer → `InvalidUserOpSignature`.
2. Implement recover + comparison with `owner`.
3. NatSpec + custom errors.

**Exit criterion:** signature suite green (valid / invalid / malformed).

**Done (2026-09-09):**
- `src/validation/SignatureValidator.sol` (library): `recoverSigner`, `isValidSignature`, `validateSignature`, `toValidationData`.
- OZ v5 ECDSA + `MessageHashUtils.toEthSignedMessageHash` (personal_sign, aligned with AA SimpleAccount).
- Reverts: `InvalidUserOpSignature`, `ZeroAddress` (owner = 0).
- ERC-4337 soft-fail via `toValidationData` → `SIG_VALIDATION_SUCCESS` / `FAILED`.
- Tests: valid, wrong signer, wrong hash, malformed, empty, raw hash without ETH prefix, e2e with `EntryPoint.getUserOpHash`, fuzz.
- **32 PASS** total (`forge test`).

---

### Phase 3 — SmartAccount ✅

**Goal:** ERC-4337 account with validation and execution only via the EntryPoint.

1. Tests first: `validateUserOp` from non-EP → `OnlyEntryPoint`.
2. `validateUserOp`: signature + (if applicable) missingAccountFunds / deposit.
3. `execute` / `executeBatch`: EntryPoint only; call failure → `ExecutionFailed`.
4. Safe owner / initialization; `immutable` EntryPoint.

**Exit criterion:** happy validation + execution; unauthorized sender covered.

**Done (2026-09-09):**
- `src/account/SmartAccount.sol`: immutable `entryPoint` + `owner`; `validateUserOp`, `execute`, `executeBatch`, deposit/nonce helpers.
- Strict auth: EntryPoint only (not even the owner directly) → `OnlyEntryPoint`.
- Signature via `SignatureValidator.toValidationData` (soft-fail `SIG_VALIDATION_FAILED`).
- Prefund: `_payPrefund(missingAccountFunds)`; failed execution → `ExecutionFailed`; invalid batch → `InvalidBatchLength`.
- Tests: unauthorized (stranger + owner), signature OK/fail, prefund, execute/batch, mock target.
- **51 PASS** total (`forge test`).

---

### Phase 4 — SponsoringPaymaster ✅

**Goal:** gas sponsorship with explicit rules.

1. Tests: insufficient deposit / expired / failed rule → `PaymasterValidationFailed`.
2. `validatePaymasterUserOp`: check deposit in EntryPoint + `validUntil` / whitelist / limits.
3. `postOp`: post-execution accounting (depending on mode).
4. Admin functions (deposit/withdraw/stake) with access control.

**Exit criterion:** sponsored UserOp OK; rejection paths green.

**Done (2026-09-10):**
- `src/paymaster/SponsoringPaymaster.sol`: whitelist, `maxCostPerOp`, `validUntil`/`validAfter` window in `paymasterAndData`, EP deposit, `postOp` + `totalSponsoredGasCost`.
- Auth: validate/postOp EntryPoint only → `OnlyEntryPoint`; admin with `Ownable2Step`.
- Unified rejections → `PaymasterValidationFailed` (no whitelist, deposit, cap, time, layout).
- Admin: `deposit`, `withdrawTo`, `addStake`, `unlockStake`, `withdrawStake`.
- Unit tests + fuzz of `maxCostPerOp` / deposit.
- **70 PASS** total (`forge test`).

---

### Phase 5 — e2e suite + unauthorized + fuzz ✅

**Goal:** testing requirements from the module's `.cursorrules`.

| Type | What it validates |
|------|-------------------|
| Unit e2e | UserOp struct → signature → EntryPoint → execution → Paymaster deduction |
| Unauthorized | `validateUserOp` / execute from != EntryPoint → `OnlyEntryPoint` |
| Fuzz | targets, calldata, Paymaster deposit bounds |

**Exit criterion:** `forge test` green; fuzz ≥ 1000 runs without unexpected failures.

**Done (2026-09-10):**
- `test/helpers/UserOpTestBase.sol` — shared build/sign/`handleOps`.
- `test/UserOpE2E.t.sol` — with/without paymaster, AA24/AA25, reverted execution, PM whitelist/deposit, value, nonce.
- `test/UnauthorizedSender.t.sol` — Account + Paymaster EntryPoint only.
- `test/fuzz/UserOp.fuzz.t.sol` — setValue/transfer/paymaster/deposit/targets (1000 runs each).
- **91 PASS** total (`forge test`).

---

### Phase 6 — Gas + Deploy + hardening ✅

1. `script/Deploy.s.sol` (Account + Paymaster + EP funding).
2. `test/gas/UserOp.gas.t.sol`: UserOp overhead vs EOA ECDSA tx (orders of magnitude / deltas).
3. Full NatSpec; `doc/SWC-AUDIT-EN.md` and `doc/GAS-EN.md` in the style of previous modules.

**Exit criterion:** reproducible local deploy + security docs + documented gas.

**Done (2026-09-10):**
- `script/Deploy.s.sol` — EntryPoint (or `ENTRY_POINT` env), SmartAccount, SponsoringPaymaster, whitelist + deposits.
- `test/gas/UserOp.gas.t.sol` + `.gas-snapshot` — EOA ~55k vs UserOp ~160k vs UserOp+PM ~200k.
- Hardening: `SmartAccount.withdrawDepositTo` (EntryPoint only) — SWC-105.
- `doc/GAS-EN.md` + `doc/SWC-AUDIT-EN.md` (SWC-100–136 matrix, module 11 style): **0 vulnerabilities**; 6 informational.
- **98 PASS** total (`forge test`).

---

## 8. Test matrix (global goal)

| Case | What it validates |
|------|-------------------|
| E2E UserOp | Full cycle with/without Paymaster |
| Unauthorized sender | `OnlyEntryPoint` |
| Invalid signature | `InvalidUserOpSignature` |
| Failed execution | `ExecutionFailed` |
| Paymaster rejects | `PaymasterValidationFailed` |
| EP nonce | Correct reuse / advance via EntryPoint |
| Fuzz calldata / deposits | No corrupted states or undue sponsorship |
| Gas profiling | Documented UserOp vs EOA delta |

---

## 9. Security (living checklist)

- [x] `msg.sender == entryPoint` in validation and execution.
- [x] ECDSA over canonical `userOpHash` (no mishandled trivial malleability).
- [x] Paymaster verifies deposit / stake per spec and business rules.
- [x] Timestamps / `validUntil`–`validAfter` respected.
- [x] Module custom errors.
- [x] No floating pragma; NatSpec on public APIs.
- [x] Unauthorized + fuzz suite.
- [x] Gas profiling + (Phase 6) SWC-AUDIT.

---

## 10. Documentation deliverables (`doc/`)

| File | Contents |
|------|----------|
| `README.md` | Bilingual index of this folder |
| `README-EN.md` | English index |
| `planificacion-EN.md` | This document (phases + gates) |
| `DECISIONES-Y-LOGICA-EN.md` | Technical decisions, logic and gas improvements |
| `diagrama-de-clases-EN.md` | Structure and relationships between contracts |
| `diagrama-de-flujo-EN.md` | Decision flows (validation, paymaster, execution) |
| `flujograma-EN.md` | End-to-end actor–system flows |
| `SWC-AUDIT-EN.md` | SWC-100–136 matrix |
| `GAS-EN.md` | Optimizations and benchmarks |
| `SOCIAL-EN.md` | Social media drafts |

Every document has a Spanish version with the `-ES.md` suffix.

Module root README: `../README-EN.md` (index: `../README.md`).

---

## 11. Module acceptance criteria

1. [x] Compiles with `pragma solidity 0.8.24`.
2. [x] Account + Paymaster operational via EntryPoint with e2e tests.
3. [x] Caller != EntryPoint can neither validate nor execute.
4. [x] Invalid signature and invalid paymaster revert / fail with custom errors (or `SIG_VALIDATION_FAILED` / EP FailedOp).
5. [x] Fuzz of targets/calldata/deposits green.
6. [x] Gas profiling documented (UserOp vs EOA).
7. [x] NatSpec + custom errors on public APIs.
8. [x] `doc/SWC-AUDIT-EN.md` with no vulnerabilities within v1 scope.

---

## 12. Next step

**Module v1 complete (Phases 0–6).** Possible extensions: account factory, guardians/recovery, VerifyingPaymaster with off-chain signature, timelock on the PM owner, Foundry invariants.

**Note:** use `~/.foundry/bin/forge` (or prepend `$HOME/.foundry/bin` to `PATH`); the nvm/npm `forge` is not Foundry.

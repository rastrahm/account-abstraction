# Technical decisions, logic and gas — Module 12 (ERC-4337)

[🇪🇸 Español](./DECISIONES-Y-LOGICA-ES.md) · 🇬🇧 English

A document to understand **what was decided**, **why**, **how the system flows**, and **where gas can still be saved**.

**v1 scope:** `SmartAccount` · `SignatureValidator` · `SponsoringPaymaster` · libs · EntryPoint v0.7 (eth-infinitism).

Related: [`flujograma-EN.md`](./flujograma-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`planificacion-EN.md`](./planificacion-EN.md)

---

## 1. Technical decisions (and why)

### 1.1 ERC-4337 **v0.7** spec (not v0.6)

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| `PackedUserOperation` | v0.6 "unpacked" UserOp | Less calldata (`accountGasLimits` / `gasFees` in `bytes32`); aligned with the current EntryPoint |
| Dependency `account-abstraction@v0.7.0` | Reimplement the EntryPoint | Don't reinvent the orchestrator; tests run against the real EP |

### 1.2 Auth: EntryPoint only

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| `msg.sender == entryPoint` in `validateUserOp`, `execute`, `executeBatch`, `withdrawDepositTo`, `validatePaymasterUserOp`, `postOp` | Also allowing the `owner` (like the SimpleAccount sample) | Prevents bypass: nobody runs account logic without going through the AA flow |
| Custom error `OnlyEntryPoint` | `require` with a string | Cheaper + monorepo style |

**Implication:** the owner signs UserOps off-chain; on-chain, only the EntryPoint "pushes" execution.

### 1.3 **Immutable** owner and EntryPoint

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| `owner` / `entryPoint` immutable in the account | Mutable storage + `transferOwnership` | Fewer SLOADs on the hot path; simple v1 |
| No account factory / proxy | CREATE2 factory + UUPS | Out of v1 scope; rotating the owner = redeploy |

### 1.4 ECDSA signature + `personal_sign` prefix

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| Signed hash = `toEthSignedMessageHash(userOpHash)` | Signing the raw `userOpHash` | Compatible with wallets / the AA SimpleAccount sample |
| OZ `tryRecover` | Manual `ecrecover` | Rejects malleability (high `s`) and invalid length |
| Soft-fail → `SIG_VALIDATION_FAILED` (1) | `revert InvalidUserOpSignature` in `validateUserOp` | The spec requires not reverting on a bad signature during validation (bundler simulation) |

`validateSignature` (reverting) exists for uses outside the EntryPoint path; the account uses `toValidationData`.

### 1.5 Nonce: EntryPoint 2D only

| Decision | Reason |
|----------|--------|
| No custom counter in the account | The EP already guarantees uniqueness with `getNonce(address, uint192)` |
| E2E tests AA25 | Replaying the same UserOp must fail |

### 1.6 Paymaster: on-chain rules (whitelist)

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| `isSponsored` whitelist + EP deposit + `maxCostPerOp` + time window | Off-chain signature only (VerifyingPaymaster) | Explicit, testable rules without an external service |
| `Ownable2Step` on the PM | Plain Ownable | Safer ownership rotation |
| `block.timestamp` + `validationData` | `validationData` only (AA recommendation) | Meet the module plan (explicit `PaymasterValidationFailed` rejection) **and** let the EP also enforce the window |

### 1.7 Execution

| Decision | Reason |
|----------|--------|
| `execute` / `executeBatch` with `.call` | Generic: any target/calldata |
| Failure → `ExecutionFailed` (no returndata bubbling) | Simple and predictable; the EP still settles gas if the UserOp reached execution |
| Batch: `values.length == 0` ⇒ value 0 | Saves calldata when no ETH is sent |

### 1.8 Errors and layout

- Module custom errors (no strings).
- Fixed pragma `0.8.24`.
- Module interfaces as typed aliases over AA (stable imports).
- Own hash in `UserOperationLib`, verified against `EntryPoint.getUserOpHash` (fuzz 1000).

---

## 2. System logic

### 2.1 Pieces

```text
Owner (EOA)  --signs-->  UserOp
                |
                v
           Bundler / test
                |
                v
         EntryPoint.handleOps
           |            |
           v            v
     SmartAccount   SponsoringPaymaster (optional)
     validateUserOp   validatePaymasterUserOp
           |            |
           +---- execute (callData) ----+
                        |
                        v
                 postOp (if a PM was used)
                        |
                        v
              Gas charge (account or PM) → beneficiary
```

### 2.2 Happy path (no paymaster)

1. **Build:** `sender = SmartAccount`, `nonce = EP.getNonce(account, 0)`, `callData = execute(target, value, data)`, v0.7 gas packs, empty `paymasterAndData`.
2. **Hash:** `userOpHash = EntryPoint.getUserOpHash(userOp)` (= module lib).
3. **Sign:** the owner signs the eth-signed hash → `userOp.signature`.
4. **handleOps:**
   - EP calls `account.validateUserOp` → checks `msg.sender == EP`, ECDSA, optionally sends `missingAccountFunds` to the EP.
   - EP consumes the nonce.
   - EP executes `callData` on the account → `execute` → `.call` to the target.
   - EP charges gas from the **account deposit** and pays the `beneficiary`.

### 2.3 Happy path (with paymaster)

Same, but `paymasterAndData` =  
`paymaster (20) || verGas (16) || postOpGas (16) || validUntil (6) || validAfter (6)`.

After validating the account, the EP:

1. Checks the paymaster deposit (≥ maxCost).
2. Calls `validatePaymasterUserOp` → whitelist, cap, time, builds `context`.
3. Executes the account.
4. Calls `postOp` → accounts `totalSponsoredGasCost`.
5. Charges gas to the **paymaster** (the account's deposit is not reduced for that op).

### 2.4 Rejection paths (summary)

| Situation | What happens |
|-----------|--------------|
| Anyone ≠ EP calls validate/execute | `OnlyEntryPoint` |
| Bad signature in validateUserOp | `validationData = 1` → EP `AA24` |
| Repeated nonce | EP `AA25` |
| Target call fails | `ExecutionFailed` (EP may still settle the op / charge gas) |
| Sender not whitelisted / low PM deposit / expired | `PaymasterValidationFailed` → EP `AA33` / `AA31` |

### 2.5 Core security invariant

> **Every privileged mutation of the account goes through the EntryPoint.**  
> The owner's signature authorizes the UserOp; it does not authorize direct calls to the contract.

---

## 3. Can the existing gas usage be improved?

Yes, but two **layers** must be separated.

### 3.1 What is not "our" overhead

The jump EOA (~55k) → UserOp (~160k) / UserOp+PM (~200k) in the snapshot comes **mostly from the EntryPoint** (`handleOps`, events, accounting).  
Optimizing only `SmartAccount.execute` will not bring a UserOp down to EOA cost: **AA always pays that toll**.

See the numbers: [`GAS-EN.md`](./GAS-EN.md).

### 3.2 Realistic improvements **inside** the module (v1 → v1.x)

| Improvement | Where | Expected impact | Cost / risk |
|-------------|-------|-----------------|-------------|
| Remove `totalSponsoredGasCost +=` (or accumulate off-chain via events) | `postOp` | Saves 1 SSTORE per sponsored UserOp | Fewer on-chain metrics |
| Don't check `block.timestamp` on-chain; only return `validationData` | Paymaster | Fewer ops + aligned with AA best practice | Loses the explicit time-based `PaymasterValidationFailed` revert |
| Whitelist via bitmap / merkle / verifyingSigner signature | Paymaster | Fewer SLOADs or fewer storage writes on onboarding | More complexity (VerifyingPaymaster style) |
| Assembly in `_call` / selective early `codesize` checks | Account | Micro-savings | Readability |
| Shorter `context` packing (fixed `abi.encodePacked`) | Paymaster | Less memory in postOp | More fragile parsing |
| `execute` without copying `data` to memory (already `calldata`) — fine today; same for batch | Account | Already reasonable | — |
| Account factory + clones (EIP-1167) | Deploy | Much cheaper account deployment | Doesn't lower per-UserOp gas |

### 3.3 **Product** improvements that also help operating gas

| Idea | Effect |
|------|--------|
| Session keys / validation cheaper than ECDSA secp256k1 | Lowers `validateUserOp` (~36k isolated today) |
| Signature aggregator (ERC-4337) | Amortizes verification across a batch |
| Well-estimated UserOp gas limits | Less prefund / fewer AA26/AA36 failures |
| Skip the paymaster if the account already has a deposit | Avoids ~40k of PM path + postOp |

### 3.4 What **not** to "optimize" blindly

| Temptation | Why not |
|------------|---------|
| Remove `OnlyEntryPoint` | Breaks the security model |
| Soft-fail → always revert in validate | Worsens bundler simulation |
| Reimplement a "lighter" EntryPoint | Out of scope; incompatibility risk |
| Lower `optimizer_runs` without measuring | May increase hot-path cost |

### 3.5 Suggested order if a gas v2 phase is opened

1. Measure again with `forge test --match-contract UserOpGasTest --gas-report` (baseline).
2. Remove or externalize `totalSponsoredGasCost` (quick win on the +PM path).
3. Evaluate a `validationData`-only paymaster (no `block.timestamp`).
4. If the product needs it: VerifyingPaymaster / session keys (structural savings, not cosmetic).

---

## 4. Mental model in one sentence

> **The owner signs; the EntryPoint commands; the account only obeys the EntryPoint; the paymaster only pays if the on-chain rules pass; the extra gas vs an EOA is the price of the AA protocol, not a bug in `setValue`.**

---

## 5. Quick code references

| Topic | File |
|-------|------|
| Auth + execute | `src/account/SmartAccount.sol` |
| ECDSA | `src/validation/SignatureValidator.sol` |
| Sponsorship | `src/paymaster/SponsoringPaymaster.sol` |
| Hash ≡ EP | `src/libraries/UserOperationLib.sol` |
| E2E logic | `test/UserOpE2E.t.sol` |
| Measured gas | `test/gas/UserOp.gas.t.sol` · `.gas-snapshot` |

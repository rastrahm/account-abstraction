# Módulo 12 — Account Abstraction (ERC-4337)

🇪🇸 Español · [🇬🇧 English](./README-EN.md) · [Índice](./README.md)

Smart Contract Account, Signature Validator y Sponsoring Paymaster sobre **ERC-4337 v0.7**, con Foundry y Solidity `0.8.24`.

**Estado:** v1 completo (Fases 0–6) · **Tests:** `forge test` → **98 PASS** · **Spec:** eth-infinitism `account-abstraction@v0.7.0`

---

## Qué incluye

| Componente | Descripción |
|------------|-------------|
| `SmartAccount` | `IAccount`: `validateUserOp` + `execute` / `executeBatch` solo vía EntryPoint |
| `SignatureValidator` | ECDSA secp256k1 sobre `userOpHash` (prefijo `personal_sign`) |
| `SponsoringPaymaster` | Whitelist, depósito EP, `validUntil`/`validAfter`, `maxCostPerOp`, `postOp` |
| Libs | `UserOperationLib` (hash ≡ EntryPoint), `ValidationDataLib` |

---

## Requisitos

- [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`)
- Usa el binario real: `export PATH="$HOME/.foundry/bin:$PATH"`  
  (el `forge` de nvm/npm **no** es Foundry)

---

## Setup

```bash
cd 12-account-abstraction
export PATH="$HOME/.foundry/bin:$PATH"

# Dependencias (gitignored en lib/)
forge install foundry-rs/forge-std --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
forge install eth-infinitism/account-abstraction@v0.7.0 --no-git --shallow

forge build
forge test
```

---

## Comandos útiles

```bash
forge test                          # suite completa (98 PASS)
forge test --match-contract UserOpE2ETest -vv
forge test --match-contract UserOpGasTest --gas-report
forge snapshot --match-contract UserOpGasTest

# Deploy local (Anvil)
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### Variables de entorno (deploy)

| Variable | Default | Uso |
|----------|---------|-----|
| `PRIVATE_KEY` | Anvil #0 | Deployer |
| `ACCOUNT_OWNER` | deployer | Owner ECDSA de la cuenta |
| `ENTRY_POINT` | (vacío → deploy nuevo) | EntryPoint existente en red |
| `ACCOUNT_DEPOSIT` | `1 ether` | Depósito cuenta en EP |
| `PAYMASTER_DEPOSIT` | `5 ether` | Depósito paymaster en EP |

---

## Estructura

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
└── doc/                    ← planificación, diagramas, SWC, gas
```

---

## Flujo rápido (UserOp)

1. Armar `PackedUserOperation` (sender = `SmartAccount`, nonce EP, `callData` = `execute(...)`).
2. Firmar `EntryPoint.getUserOpHash(userOp)` con el owner (`personal_sign`).
3. Opcional: `paymasterAndData` = paymaster + gas limits + `validUntil||validAfter`.
4. `entryPoint.handleOps([userOp], beneficiary)`.

Auth on-chain: solo el EntryPoint puede llamar `validateUserOp` / `execute` / `validatePaymasterUserOp` / `postOp`.

---

## Gas (baseline Fase 6)

| Path | Gas (snapshot) |
|------|----------------|
| EOA `setValue` | ~54 582 |
| UserOp (sin PM) | ~159 870 (~2.9×) |
| UserOp + Paymaster | ~199 504 (~3.7×) |

Detalle: [`doc/GAS-ES.md`](./doc/GAS-ES.md)

---

## Seguridad

Auditoría SWC-100–136: **0 vulnerabilidades** en alcance v1.  
Ver [`doc/SWC-AUDIT-ES.md`](./doc/SWC-AUDIT-ES.md).

Errores custom: `OnlyEntryPoint`, `ExecutionFailed`, `InvalidUserOpSignature`, `PaymasterValidationFailed`, `ZeroAddress`, `InvalidBatchLength`.

---

## Documentación

Índice completo: [`doc/README-ES.md`](./doc/README-ES.md)

**Página de portafolio (ES/EN):** [`portfolio/index.html`](./portfolio/index.html)

| Doc | Contenido |
|-----|-----------|
| [planificacion-ES.md](./doc/planificacion-ES.md) | Fases 0–6, gates, criterios |
| [DECISIONES-Y-LOGICA-ES.md](./doc/DECISIONES-Y-LOGICA-ES.md) | Decisiones técnicas, flujo, mejoras de gas |
| [diagrama-de-clases-ES.md](./doc/diagrama-de-clases-ES.md) | UML Mermaid |
| [diagrama-de-flujo-ES.md](./doc/diagrama-de-flujo-ES.md) | Decisiones validate / PM / execute |
| [flujograma-ES.md](./doc/flujograma-ES.md) | Ciclo e2e actores |
| [SWC-AUDIT-ES.md](./doc/SWC-AUDIT-ES.md) | Matriz SWC |
| [GAS-ES.md](./doc/GAS-ES.md) | Benchmarks y opts |
| [SOCIAL-ES.md](./doc/SOCIAL-ES.md) | Borradores LinkedIn / X |

---

## Stack

- Solidity `0.8.24` · Foundry · Cancun
- OpenZeppelin Contracts **v5.2.0**
- account-abstraction **v0.7.0** (`PackedUserOperation`)

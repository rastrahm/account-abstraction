# Documentation — Module 12: Account Abstraction (ERC-4337)

[🇪🇸 Español](./README-ES.md) · 🇬🇧 English · [Index](./README.md)

Index of the `doc/` folder. **Complete project** (contracts + security + gas).

| Document | Contents |
|----------|----------|
| [planificacion-EN.md](./planificacion-EN.md) | Goal, scope, TDD phases, gates, criteria |
| [DECISIONES-Y-LOGICA-EN.md](./DECISIONES-Y-LOGICA-EN.md) | Technical decisions, logical flow, gas improvements |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | UML: Account, Paymaster, EntryPoint, libs |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | validateUserOp / paymaster / execute flows |
| [flujograma-EN.md](./flujograma-EN.md) | E2E cycle Build → Sign → handleOps → Settle |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix, mapping to tests |
| [GAS-EN.md](./GAS-EN.md) | EOA vs UserOp baseline, snapshot, optimizations |
| [SOCIAL-EN.md](./SOCIAL-EN.md) | LinkedIn / X drafts |

**Web portfolio:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN)

**Status:** Phases **0–6** ✅ (module closed, v1).

**Contracts:** `SmartAccount` · `SponsoringPaymaster` · `SignatureValidator` · `UserOperationLib` · `ValidationDataLib`  
**Standard:** ERC-4337 **v0.7** · **Tests:** `forge test` → **98 PASS** · incl. e2e / unauthorized / fuzz / gas

Project README: [`../README-EN.md`](../README-EN.md)

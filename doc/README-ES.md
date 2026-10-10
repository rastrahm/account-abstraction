# Documentación — Módulo 12: Account Abstraction (ERC-4337)

🇪🇸 Español · [🇬🇧 English](./README-EN.md) · [Índice](./README.md)

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [planificacion-ES.md](./planificacion-ES.md) | Objetivo, alcance, fases TDD, gates, criterios |
| [DECISIONES-Y-LOGICA-ES.md](./DECISIONES-Y-LOGICA-ES.md) | Decisiones técnicas, flujo lógico, mejoras de gas |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | UML: Account, Paymaster, EntryPoint, libs |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Flujos validateUserOp / paymaster / execute |
| [flujograma-ES.md](./flujograma-ES.md) | Ciclo e2e Build → Sign → handleOps → Settle |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS-ES.md](./GAS-ES.md) | Baseline EOA vs UserOp, snapshot, opts |
| [SOCIAL-ES.md](./SOCIAL-ES.md) | Borradores LinkedIn / X |

**Portfolio web:** [`../portfolio/index.html`](../portfolio/index.html) (ES/EN)

**Estado:** Fases **0–6** ✅ (módulo cerrado v1).

**Contratos:** `SmartAccount` · `SponsoringPaymaster` · `SignatureValidator` · `UserOperationLib` · `ValidationDataLib`  
**Estándar:** ERC-4337 **v0.7** · **Tests:** `forge test` → **98 PASS** · incl. e2e / unauthorized / fuzz / gas

README del proyecto: [`../README-ES.md`](../README-ES.md)

# Documentación — Módulo 12: Account Abstraction (ERC-4337)

Índice de la carpeta `doc/`. **Proyecto completo** (contratos + seguridad + gas).

| Documento | Contenido |
|-----------|-----------|
| [planificacion.md](./planificacion.md) | Objetivo, alcance, fases TDD, gates, criterios |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: Account, Paymaster, EntryPoint, libs |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Flujos validateUserOp / paymaster / execute |
| [flujograma.md](./flujograma.md) | Ciclo e2e Build → Sign → handleOps → Settle |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136, mapeo a tests |
| [GAS.md](./GAS.md) | Baseline EOA vs UserOp, snapshot, opts |

**Estado:** Fases **0–6** ✅ (módulo cerrado v1).

**Contratos:** `SmartAccount` · `SponsoringPaymaster` · `SignatureValidator` · `UserOperationLib` · `ValidationDataLib`  
**Estándar:** ERC-4337 **v0.7** · **Tests:** `forge test` → **98 PASS** · incl. e2e / unauthorized / fuzz / gas

README del proyecto: [`../README.md`](../README.md)

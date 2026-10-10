# Borradores redes — Account Abstraction ERC-4337 (módulo 12)

🇪🇸 Español · [🇬🇧 English](./SOCIAL-EN.md)

Links:

- **GitHub:** https://github.com/rastrahm/account-abstraction  
- **GitLab:** https://gitlab.com/rastrahm/account-abstraction  

> Si publicás un artículo largo (Medium/Hashnode/Mirror), poné esa URL como link principal y dejá los repos como “código”.

---

## LinkedIn (tono humano)

Publiqué el módulo 12 de mi suite de smart contracts: **Account Abstraction (ERC-4337 v0.7)** en Solidity 0.8.24 y Foundry.

Esto lo fui armando de noche, entre el laburo y lo demás. Si a alguien le sirve el repo, genial: lo dejé abierto en GitHub y GitLab.

La idea no era solo “una wallet con contrato”. Quería entender el ciclo completo: armar el UserOp, firmar el `userOpHash`, que el EntryPoint valide, ejecutar… y que un paymaster pueda bancar el gas con reglas claras.

Qué quedó adentro:

- `SmartAccount`: validate + execute solo si llama el EntryPoint  
- Firma ECDSA sobre el hash canónico (estilo `personal_sign`)  
- `SponsoringPaymaster`: whitelist, depósito, ventana de validez y tope de coste  
- Suite e2e, unauthorized, fuzz (1000), gas (UserOp vs EOA) y auditoría SWC  

También dejé planificación, diagramas y docs, porque en AA la confianza se gana mostrando el diseño, no solo un “tests green”.

Código (mismo proyecto en ambos lados):

GitHub → https://github.com/rastrahm/account-abstraction  
GitLab → https://gitlab.com/rastrahm/account-abstraction  

Si te interesa, ¿qué preferís que desarrolle en un próximo post: el flujo del UserOp, el paymaster, o por qué `msg.sender == entryPoint` es tan crítico?

\#Solidity \#Foundry \#Web3 \#AccountAbstraction \#ERC4337 \#SmartContracts \#Ethereum \#Paymaster \#OpenZeppelin

---

## X / Twitter — 144 caracteres (con ambos repos)

```
Publiqué ERC-4337 (cuenta+paymaster). Lo armé de noche.
github.com/rastrahm/account-abstraction
gitlab.com/rastrahm/account-abstraction
```

*(116 caracteres; links sin `https://` para entrar cómodo en el límite.)*

### Alternativa si X cuenta URLs acortadas distinto

```
ERC-4337 AA · Foundry · hecho de noche
https://github.com/rastrahm/account-abstraction
https://gitlab.com/rastrahm/account-abstraction
```

> En X las URLs suelen contar como ~23 caracteres cada una (t.co). Si tu cliente aplica eso, la versión con `https://` también entra.

const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Account Abstraction ERC-4337 — Rolando Strahm',
    'meta.description':
      'Smart Account ERC-4337 v0.7, Sponsoring Paymaster, gas (UserOp vs EOA) y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 12 · PORTFOLIO WEB3',
    'hero.title': 'ACCOUNT<br>ABSTRACTION',
    'hero.role': 'ERC-4337 v0.7 · Smart Account · Paymaster · Foundry',
    'hero.sub':
      'Smart Account + Signature Validator + Sponsoring Paymaster con EntryPoint-only auth, gas documentado (UserOp vs EOA) y auditoría defensiva SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Las wallets no tienen por qué ser solo EOAs. Este módulo implementa <strong>ERC-4337 v0.7</strong> con Foundry: UserOp firmada, validación en la cuenta, ejecución vía <strong>EntryPoint</strong> y un <strong>paymaster</strong> que puede patrocinar gas — cerrando con <strong>gas</strong> (overhead vs EOA) y <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Account + Paymaster',
    'p1.desc':
      'SmartAccount (IAccount), SignatureValidator ECDSA y SponsoringPaymaster con whitelist, depósito y ventana temporal.',
    'p1.l1': 'Solo EntryPoint valida / ejecuta',
    'p1.l2': 'userOpHash ≡ EntryPoint.getUserOpHash',
    'p1.l3': 'PackedUserOperation (v0.7)',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Immutables, custom errors, calldata y soft-fail de firma; baseline EOA vs UserOp vs UserOp+Paymaster en snapshot.',
    'p2.l1': 'EOA ~55k · UserOp ~160k · +PM ~200k',
    'p2.l2': 'entryPoint / owner immutable',
    'p2.l3': 'Gas report + .gas-snapshot',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136 con foco en auth EntryPoint, ECDSA anti-malleability, replay (nonce) y withdrawals protegidos.',
    'p3.l1': '30 mitigados / N/A · 6 informativos',
    'p3.l2': '0 vulnerabilidades explotables',
    'p3.l3': 'Unauthorized + e2e + fuzz 1000',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Overhead AA medido, no inventado',
    'gas.lead':
      'Fase 6: cada técnica está en <code>doc/GAS-ES.md</code> con su <strong>tradeoff</strong>. El coste extra no es el <code>setValue</code>: es <strong>EntryPoint.handleOps</strong> (validación, prefund, eventos, liquidación). Baseline Foundry para el mismo efecto on-chain.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'entryPoint / owner immutable (SmartAccount)',
    'gas.r1b': 'Sin SLOAD en hot path de auth y firma',
    'gas.r2a': 'entryPoint immutable (SponsoringPaymaster)',
    'gas.r2b': 'Misma idea en validate / postOp / depósitos',
    'gas.r3a': 'ECDSA OZ tryRecover + eth-signed hash',
    'gas.r3b': 'Anti-malleability; soft-fail sin revert caro en simulación',
    'gas.r4a': 'Firma inválida → validationData (no revert)',
    'gas.r4b': 'Compatible con simulación bundler (SIG_VALIDATION_FAILED)',
    'gas.r5a': 'PackedUserOperation (gas fees / limits en bytes32)',
    'gas.r5b': 'Menos calldata vs UserOp “unpacked” de v0.6',
    'gas.r6a': 'calldata en execute / validate + custom errors',
    'gas.r6b': 'Menos copias memory; reverts más baratos que require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo; deploy un poco más caro a cambio de runtime',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra SmartAccount, SignatureValidator y SponsoringPaymaster. Informe en <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong>; auth estricta <code>msg.sender == entryPoint</code>.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r105': 'Withdraws protegidos: withdrawDepositTo solo EP; PM withdrawTo onlyOwner',
    'swc.r117': 'OZ tryRecover + compare owner; anti-malleability s',
    'swc.r121': 'Replay: userOpHash (EP+chainId) + nonce 2D EntryPoint (AA25)',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / unauthorized',
    'swc.r115': 'Auth por msg.sender == entryPoint / Ownable2Step, sin tx.origin',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'block.timestamp (paymaster)',
    'swc.i1d':
      'El paymaster chequea tiempo on-chain y además empaqueta validUntil/validAfter para el EntryPoint. Usar márgenes en la ventana.',
    'swc.i2t': 'Orden / bundling',
    'swc.i2d':
      'Los UserOps compiten en mempools de bundlers. No es bypass de firma: mitigación operativa con relays / políticas del bundler.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–6 cerradas',
    'pr.lead':
      'Desarrollo por gates: setup Foundry + AA v0.7, hash/interfaces, firma, SmartAccount, Paymaster, e2e/fuzz/unauthorized y deploy + gas + SWC.',
    'ph.0': 'Bootstrap Foundry + AA v0.7',
    'ph.12': 'UserOp hash + SignatureValidator',
    'ph.34': 'SmartAccount + Paymaster',
    'ph.5': 'E2E · unauthorized · fuzz',
    'ph.6': 'Deploy · gas · SWC',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/12-account-abstraction',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 98 passed',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 6 · Mitigados/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_12_CLOSED · ERC4337_V0.7',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suite unauthorized + e2e: el “éxito” del ataque es que revierta. Sin PoCs de exploit — OnlyEntryPoint, AA24/AA25, paymaster rechazado y firmas inválidas.',
    'cA.t': 'Unauthorized',
    'cA.d': 'EOA / owner no pueden validateUserOp ni execute directo.',
    'cB.t': 'Bad signature',
    'cB.d': 'Firma inválida → AA24 / SIG_VALIDATION_FAILED.',
    'cC.t': 'Replay nonce',
    'cC.d': 'Reuso de nonce → AA25 invalid account nonce.',
    'cD.t': 'Paymaster deny',
    'cD.d': 'Sin whitelist / depósito bajo → FailedOp / AA33.',
    'cE.t': 'Fuzz bounds',
    'cE.d': 'Calldata, value y depósitos PM sin estados corruptos.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'El mismo código está en GitHub y GitLab: Account, Paymaster, tests, gas, auditoría SWC y diagramas.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Account Abstraction · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Account Abstraction ERC-4337 — Rolando Strahm',
    'meta.description':
      'ERC-4337 v0.7 Smart Account, Sponsoring Paymaster, gas (UserOp vs EOA), and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 12 · WEB3 PORTFOLIO',
    'hero.title': 'ACCOUNT<br>ABSTRACTION',
    'hero.role': 'ERC-4337 v0.7 · Smart Account · Paymaster · Foundry',
    'hero.sub':
      'Smart Account + Signature Validator + Sponsoring Paymaster with EntryPoint-only auth, documented gas (UserOp vs EOA), and defensive SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'Wallets do not have to be EOAs only. This module implements <strong>ERC-4337 v0.7</strong> with Foundry: signed UserOp, account validation, execution via <strong>EntryPoint</strong>, and a <strong>paymaster</strong> that can sponsor gas — closing with <strong>gas</strong> (overhead vs EOA) and <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module delivers',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Account + Paymaster',
    'p1.desc':
      'SmartAccount (IAccount), ECDSA SignatureValidator, and SponsoringPaymaster with whitelist, deposit, and time window.',
    'p1.l1': 'Only EntryPoint validates / executes',
    'p1.l2': 'userOpHash ≡ EntryPoint.getUserOpHash',
    'p1.l3': 'PackedUserOperation (v0.7)',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Immutables, custom errors, calldata, and signature soft-fail; EOA vs UserOp vs UserOp+Paymaster snapshot baseline.',
    'p2.l1': 'EOA ~55k · UserOp ~160k · +PM ~200k',
    'p2.l2': 'immutable entryPoint / owner',
    'p2.l3': 'Gas report + .gas-snapshot',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix focused on EntryPoint auth, anti-malleable ECDSA, replay (nonce), and protected withdrawals.',
    'p3.l1': '30 mitigated / N/A · 6 informational',
    'p3.l2': '0 exploitable vulnerabilities',
    'p3.l3': 'Unauthorized + e2e + fuzz 1000',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Measured AA overhead, not guessed',
    'gas.lead':
      'Phase 6: every technique is in <code>doc/GAS-EN.md</code> with its <strong>tradeoff</strong>. The extra cost is not <code>setValue</code> — it is <strong>EntryPoint.handleOps</strong> (validation, prefund, events, settlement). Foundry baseline for the same on-chain effect.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'immutable entryPoint / owner (SmartAccount)',
    'gas.r1b': 'No SLOAD on auth and signature hot path',
    'gas.r2a': 'immutable entryPoint (SponsoringPaymaster)',
    'gas.r2b': 'Same idea on validate / postOp / deposits',
    'gas.r3a': 'OZ ECDSA tryRecover + eth-signed hash',
    'gas.r3b': 'Anti-malleability; soft-fail without expensive revert in simulation',
    'gas.r4a': 'Invalid signature → validationData (no revert)',
    'gas.r4b': 'Bundler-simulation friendly (SIG_VALIDATION_FAILED)',
    'gas.r5a': 'PackedUserOperation (gas fees / limits in bytes32)',
    'gas.r5b': 'Less calldata than unpacked v0.6 UserOp',
    'gas.r6a': 'calldata on execute / validate + custom errors',
    'gas.r6b': 'Fewer memory copies; cheaper reverts than require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive inlining; slightly costlier deploy for better runtime',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full <strong>SWC-100 → SWC-136</strong> matrix against SmartAccount, SignatureValidator, and SponsoringPaymaster. Report in <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong>; strict <code>msg.sender == entryPoint</code> auth.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r105': 'Protected withdrawals: withdrawDepositTo EntryPoint-only; PM withdrawTo onlyOwner',
    'swc.r117': 'OZ tryRecover + owner compare; anti-malleable s',
    'swc.r121': 'Replay: userOpHash (EP+chainId) + EntryPoint 2D nonce (AA25)',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / unauthorized',
    'swc.r115': 'Auth via msg.sender == entryPoint / Ownable2Step, no tx.origin',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'block.timestamp (paymaster)',
    'swc.i1d':
      'The paymaster checks time on-chain and also packs validUntil/validAfter for the EntryPoint. Use margins in the window.',
    'swc.i2t': 'Ordering / bundling',
    'swc.i2d':
      'UserOps compete in bundler mempools. Not a signature bypass: operational mitigation via relays / bundler policy.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–6 closed',
    'pr.lead':
      'Gated development: Foundry + AA v0.7 setup, hash/interfaces, signature, SmartAccount, Paymaster, e2e/fuzz/unauthorized, then deploy + gas + SWC.',
    'ph.0': 'Foundry bootstrap + AA v0.7',
    'ph.12': 'UserOp hash + SignatureValidator',
    'ph.34': 'SmartAccount + Paymaster',
    'ph.5': 'E2E · unauthorized · fuzz',
    'ph.6': 'Deploy · gas · SWC',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/12-account-abstraction',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 98 passed',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 6 · Mitigated/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_12_CLOSED · ERC4337_V0.7',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'Unauthorized + e2e suites: a successful “attack” means it reverts. No exploit PoCs — OnlyEntryPoint, AA24/AA25, rejected paymaster, and invalid signatures.',
    'cA.t': 'Unauthorized',
    'cA.d': 'EOA / owner cannot call validateUserOp or execute directly.',
    'cB.t': 'Bad signature',
    'cB.d': 'Invalid signature → AA24 / SIG_VALIDATION_FAILED.',
    'cC.t': 'Replay nonce',
    'cC.d': 'Nonce reuse → AA25 invalid account nonce.',
    'cD.t': 'Paymaster deny',
    'cD.d': 'No whitelist / low deposit → FailedOp / AA33.',
    'cE.t': 'Fuzz bounds',
    'cE.d': 'Calldata, value, and PM deposits without corrupt state.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'The same codebase is on GitHub and GitLab: Account, Paymaster, tests, gas, SWC audit, and diagrams.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Account Abstraction · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('aa-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('aa-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);

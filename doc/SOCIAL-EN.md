# Social drafts — Account Abstraction ERC-4337 (module 12)

[🇪🇸 Español](./SOCIAL-ES.md) · 🇬🇧 English

Links:

- **GitHub:** https://github.com/rastrahm/account-abstraction  
- **GitLab:** https://gitlab.com/rastrahm/account-abstraction  

> If you publish a long-form article (Medium/Hashnode/Mirror), use that URL as the main link and keep the repos as "code".

---

## LinkedIn (human tone)

I just published module 12 of my smart contracts suite: **Account Abstraction (ERC-4337 v0.7)** in Solidity 0.8.24 and Foundry.

I built this at night, between work and everything else. If the repo helps anyone, great: it's open on both GitHub and GitLab.

The goal wasn't just "a wallet with a contract". I wanted to understand the full cycle: build the UserOp, sign the `userOpHash`, have the EntryPoint validate it, execute… and let a paymaster cover the gas with clear rules.

What made it in:

- `SmartAccount`: validate + execute only when the EntryPoint calls  
- ECDSA signature over the canonical hash (`personal_sign` style)  
- `SponsoringPaymaster`: whitelist, deposit, validity window and cost cap  
- E2E, unauthorized, fuzz (1000), gas (UserOp vs EOA) suites and an SWC audit  

I also included planning, diagrams and docs, because in AA trust is earned by showing the design, not just "tests green".

Code (same project on both):

GitHub → https://github.com/rastrahm/account-abstraction  
GitLab → https://gitlab.com/rastrahm/account-abstraction  

If you're interested, what would you like me to dig into in a next post: the UserOp flow, the paymaster, or why `msg.sender == entryPoint` is so critical?

\#Solidity \#Foundry \#Web3 \#AccountAbstraction \#ERC4337 \#SmartContracts \#Ethereum \#Paymaster \#OpenZeppelin

---

## X / Twitter — 144 characters (with both repos)

```
Shipped ERC-4337 (account+paymaster). Built at night.
github.com/rastrahm/account-abstraction
gitlab.com/rastrahm/account-abstraction
```

*(133 characters; links without `https://` to fit comfortably within the limit.)*

### Alternative if X counts shortened URLs differently

```
ERC-4337 AA · Foundry · built at night
https://github.com/rastrahm/account-abstraction
https://gitlab.com/rastrahm/account-abstraction
```

> On X, URLs usually count as ~23 characters each (t.co). If your client applies that, the `https://` version also fits.

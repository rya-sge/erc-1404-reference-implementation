# Aderyn Report — Feedback & Triage

**Scope**: `src/` — `ERC1404.sol`, `IERC1404.sol`, `engine/IERC1404Restriction.sol`, `engine/RestrictedToken.sol`, `engine/WhitelistRuleEngine.sol`
**Tool**: [Aderyn](https://github.com/Cyfrin/aderyn) `0.6.5` static analysis (mocks excluded, `-x mocks`)
**Date reviewed**: 2026-07-08

---

## Summary

| ID  | Title                              | Severity | Instances | Disposition |
|-----|------------------------------------|----------|-----------|-------------|
| H-1 | Arbitrary `from` in `transferFrom` | High     | 1         | **False positive** |
| L-1 | Centralization Risk                | Low      | 9         | **By design** |
| L-2 | Unsafe ERC20 Operation             | Low      | 1         | **False positive** |
| L-3 | Unspecific Solidity Pragma         | Low      | 5         | **By design** |
| L-4 | PUSH0 Opcode                       | Low      | 5         | **By design / conditional** |

---

## High Issues

### H-1 — Arbitrary `from` Passed to `transferFrom`

**Disposition: False positive**

Aderyn flags `super.transferFrom(from, to, value)` at `src/ERC1404.sol:148`. This is the standard static-analysis false positive for ERC20 overrides.

Verified against source: the override first calls `_checkRestriction(from, to, value)` and then delegates to OpenZeppelin's `ERC20.transferFrom`, which internally calls `_spendAllowance(from, msg.sender, value)`. A caller cannot move another account's tokens without an allowance granted by `from`. No path bypasses the allowance check.

`RestrictedToken` does not override `transferFrom`; it inherits OZ's implementation (same `_spendAllowance` guarantee) and enforces restrictions in the `_update` hook. Not flagged, and equally safe.

**No action required.**

---

## Low Issues

### L-1 — Centralization Risk

**Disposition: By design**

9 instances across the owner-gated entry points of all three concrete contracts: `ERC1404` (`setWhitelisted`, `mint`, `burn`), `RestrictedToken` (`mint`, `burn`), and `WhitelistRuleEngine` (`setWhitelisted`). ERC-1404 is a permissioned standard for regulated / restricted transfers; a privileged whitelist administrator is the intended compliance control, not a defect.

Optional hardening (already noted in the README "Limitations"): use a multisig/timelock as owner, and prefer `Ownable2Step` over `Ownable`.

**No action required.**

---

### L-2 — Unsafe ERC20 Operation

**Disposition: False positive**

Flags `super.transfer(to, value)` at `src/ERC1404.sol:140`. `SafeERC20` is intended for *external* calls to third-party tokens that may not conform to the standard (e.g. no return value). Here `super.transfer` is an internal call to OpenZeppelin's own `ERC20.transfer`, which returns `true` or reverts — it never silently fails. Wrapping it in `SafeERC20` would be meaningless.

**No action required.**

---

### L-3 — Unspecific Solidity Pragma

**Disposition: By design**

5 instances — every first-party `src/` file uses `pragma solidity ^0.8.20;`. This is deliberate for a reference implementation: the caret sets a minimum-compatibility floor for integrators, while the exact compiler is pinned by the build (`foundry.toml` → `solc = "0.8.34"`). Pinning the pragma would force every downstream consumer onto one exact version.

**No action required.**

---

### L-4 — PUSH0 Opcode

**Disposition: By design / conditional**

5 instances. `foundry.toml` explicitly sets `evm_version = 'prague'`, so the emitted bytecode intentionally targets a modern EVM (Shanghai onward), which includes `PUSH0`. This is correct for Ethereum mainnet and current L2s.

Only relevant if an integrator intends to deploy to a pre-Shanghai chain — in which case they set `evm_version = "paris"` in their own config and re-verify. That is a downstream deployment decision, not a code defect.

**No action required.**

---

## Executive triage

**Nothing is exploitable and nothing needs a code change.** H-1 and L-2 are ERC20-override false positives (allowance enforcement + internal OZ call). L-1 is the intended permissioned-token model. L-3 and L-4 are deliberate reference-implementation / build-configuration choices. The `evm_version` and ownership-hardening notes are already documented in the README "Limitations" section.

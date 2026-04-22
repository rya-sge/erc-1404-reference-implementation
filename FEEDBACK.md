# Feedback — ERC-1404 Reference Implementation

*Written from the perspective of a developer using this repo as the starting point for a production ERC-1404 token.*

---

## What works well

- **Clean separation between interface and implementation.** `IERC1404.sol` is a self-contained contract interface that I can import without pulling in any logic. Good starting point for a real project.
- **OZ Ownable integration.** Using the battle-tested OZ `Ownable` rather than a hand-rolled owner pattern is the right call for a reference.
- **ERC-165 support.** Included by default and tested — this is easy to forget and matters for on-chain integrations.
- **Named constants for codes and messages.** Having `SENDER_NOT_WHITELISTED` and `MESSAGE_SENDER_NOT_WHITELISTED` as public constants means my off-chain code can read them from the contract rather than hardcoding magic numbers or strings.
- **Test coverage of the spec's required cases.** All five cases from `erc-1404.md` are present in the test file.

---

## Issues and suggestions

### 1. `renounceOwnership` is silently inherited and dangerous

`Ownable` exposes `renounceOwnership()`, which permanently sets `owner = address(0)`. This is just as destructive as the `transferOwnership(address(0))` guard we added, yet it is not overridden here. A developer copying this reference will inherit it without realising it exists.

**Suggestion:** Override and revert, or at minimum document it explicitly.

```solidity
/// @dev Disabled — renouncing ownership permanently freezes whitelist management.
function renounceOwnership() public pure override {
    revert("ERC1404: renounce not allowed");
}
```

---

### 2. The `value` parameter of `detectTransferRestriction` is silently ignored

The function signature accepts `value` but discards it with a `/* value */` comment. As an implementer, I am likely to need amount-based restrictions — daily transfer limits, minimum transfer sizes, or lock-up thresholds — and I have no guidance on how to wire `value` into my restriction logic or whether there are any gotchas.

**Suggestion:** Add a short inline comment explaining the design choice, and ideally show a one-line example in the NatSpec of what an amount-based check might look like.

---

### 3. No NatSpec on public functions

As a reference implementation, this is the first place I look to understand expected behavior. None of the public functions have `@notice`, `@param`, or `@return` documentation. I have to cross-reference `erc-1404.md` manually to understand what `detectTransferRestriction` is supposed to do, what constitutes a valid return value, or what `messageForTransferRestriction` is expected to return for unknown codes.

**Suggestion:** Add minimal NatSpec to `IERC1404.sol` at minimum — that is the contract interface other developers will import.

---

### 4. `setWhitelisted` accepts `address(0)` without a guard

Whitelisting `address(0)` would allow unrestricted token burns (transfers to the zero address). It is unlikely to be intentional. If the deployer passes `address(0)` by mistake the error is silent.

**Suggestion:**

```solidity
function setWhitelisted(address account, bool status) external onlyOwner {
    if (account == address(0)) revert AddressZeroNotAllowed();
    whitelist[account] = status;
    emit WhitelistUpdated(account, status);
}
```

---

### 5. No guidance on extending restriction codes

The spec reserves 256 codes (`uint8`). This reference uses three (`0`, `1`, `2`). As an implementer building a real compliance token, I need to add codes for jurisdiction checks, lock-up periods, KYC expiry, and so on. There is no guidance on the recommended pattern:

- Should I define more `uint8` constants in the same contract?
- Should I define them in a separate library?
- Is there a community convention for reserved code ranges?

**Suggestion:** Add a short section in the README or a comment block documenting the allocation strategy — for example, reserving `0–9` for core transfer checks and leaving `10–255` for implementer-defined restrictions.

---

### 6. `Ownable2Step` would be safer for a compliance token

`Ownable` transfers ownership immediately in a single transaction. For a token issuer managing a compliance whitelist, accidentally transferring ownership to the wrong address is a serious operational risk with no recovery. `Ownable2Step` (also in OZ) requires the new owner to call `acceptOwnership()`, making accidental transfers recoverable.

**Suggestion:** Consider switching to `Ownable2Step` and document the rationale for whichever choice is made.

---

### 7. No deploy script

The `script/` directory is empty. A reference implementation without a deployment script leaves implementers to figure out constructor arguments on their own. For a standard where the deployer's address is automatically whitelisted and the initial supply is minted, the deployment parameters matter.

**Suggestion:** Add a minimal `ERC1404.s.sol` showing how to deploy with a name, symbol, and initial supply, and how to whitelist a first set of addresses after deployment.

---

### 8. Tests assert hardcoded strings instead of constants

The tests compare against string literals:

```solidity
assertEq(token.messageForTransferRestriction(1), "Sender not whitelisted");
```

Since the contract now exposes the messages as public constants (`MESSAGE_SENDER_NOT_WHITELISTED`), the test could reference them:

```solidity
assertEq(token.messageForTransferRestriction(1), token.MESSAGE_SENDER_NOT_WHITELISTED());
```

This makes the tests resilient to message wording changes and makes it clear to an implementer that the constants are the source of truth.

---

### 9. No example of mint / burn with restriction enforcement

The reference mints the full supply in the constructor and exposes no further `mint` or `burn` functions. In practice, compliance tokens need ongoing issuance (e.g., for new investors) and redemption (e.g., for exits). There is no guidance on whether minting and burning should also run through `detectTransferRestriction`, or bypass it.

**Suggestion:** Either add a guarded `mint(address to, uint256 amount)` as an example, or explicitly document that minting/burning is out of scope and link to the relevant OZ extension patterns.

---

### 10. `_checkRestriction` eagerly builds the error message string

```solidity
revert TransferRestricted(code, messageForTransferRestriction(code));
```

`messageForTransferRestriction` is called unconditionally on every failed transfer, allocating the message string in memory even though the caller often only needs the `code`. For a reference implementation this is acceptable, but it is worth documenting so implementers do not replicate the pattern in gas-sensitive paths.

---

## Summary

| # | Severity | Topic |
|---|----------|-------|
| 1 | High | `renounceOwnership` not disabled |
| 2 | Medium | `value` parameter silently ignored — no guidance |
| 3 | Medium | No NatSpec on public interface |
| 4 | Medium | `setWhitelisted(address(0))` not guarded |
| 5 | Medium | No guidance on restriction code allocation |
| 6 | Low | `Ownable2Step` would be safer |
| 7 | Low | No deploy script |
| 8 | Low | Test strings not referencing constants |
| 9 | Low | No mint/burn example |
| 10 | Info | Eager message string allocation in error path |

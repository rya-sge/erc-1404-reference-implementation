# ERC-1404 Reference Implementation

A minimal, auditable reference implementation of [EIP-1404](https://eips.ethereum.org/EIPS/eip-1404) — Simple Restricted Token Standard — built with Foundry and OpenZeppelin Contracts v5.

## Overview

ERC-1404 extends ERC-20 with two functions that allow token issuers to enforce transfer restrictions on-chain while providing machine-readable status codes and human-readable messages to callers. This is useful for securities, real-world assets, and any token that must enforce compliance rules such as KYC/AML checks, lock-up periods, or jurisdiction-based allowlists.

The standard adds:

```solidity
function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);
function messageForTransferRestriction(uint8 restrictionCode) external view returns (string memory);
```

A return value of `0` from `detectTransferRestriction` means the transfer is unrestricted. Any non-zero value is a restriction code, and `transfer`/`transferFrom` MUST revert (or return `false`) when one is returned.

## Contracts

| File | Description |
|------|-------------|
| `src/IERC1404.sol` | Interface — extends `IERC20` with the two ERC-1404 functions |
| `src/ERC1404.sol` | Concrete implementation — whitelist-based, with ERC-165 support |

### Restriction codes

| Code | Constant | Message |
|------|----------|---------|
| `0` | `TRANSFER_OK` | No restriction |
| `1` | `SENDER_NOT_WHITELISTED` | Sender not whitelisted |
| `2` | `RECIPIENT_NOT_WHITELISTED` | Recipient not whitelisted |

### Design decisions

- **Whitelist policy** — both sender and recipient must be explicitly whitelisted. The deployer is added to the whitelist at construction.
- **Revert on restriction** — `transfer` and `transferFrom` revert with a typed `TransferRestricted(uint8 code, string message)` error rather than returning `false`, as recommended by the spec.
- **Sender checked before recipient** — `detectTransferRestriction` evaluates the sender first, so callers can distinguish the two failure cases with a single view call before submitting a transaction.
- **ERC-165** — `supportsInterface(0xab84a5c8)` returns `true`, enabling on-chain interface discovery.
- **Minimal ownership** — a single `owner` address controls the whitelist. Ownership is transferable. No role hierarchy is imposed, keeping the implementation easy to audit and extend.

## Install dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

## Build

```bash
forge build
```

## Test

```bash
forge test -vv
```

## Gas report

```bash
forge test --gas-report
```

## Coverage

```bash
forge coverage
```

## Limitations

This is a minimal reference implementation. The following are known constraints to consider before using it in production.

- **Single owner, no multisig or timelock.** The whitelist is controlled by one address. A compromised or malicious owner can freeze any holder's tokens instantly with no delay or governance check.
- **`renounceOwnership` is active.** Inherited from OZ `Ownable`, calling it permanently sets `owner = address(0)` and irreversibly freezes whitelist management.
- **Ownership transfer is immediate.** `transferOwnership` takes effect in a single transaction. Transferring to a wrong address is not recoverable. Consider `Ownable2Step` for production use.
- **`value` is not used in restriction logic.** `detectTransferRestriction` ignores the token amount. Amount-based restrictions (transfer limits, lock-up thresholds) require subclassing and overriding that function.
- **No upgrade path.** The whitelist policy is hardcoded. Changing restriction logic requires deploying a new contract and migrating token holders.

## License

CC0-1.0

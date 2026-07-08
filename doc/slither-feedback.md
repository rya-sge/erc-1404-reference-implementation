# Slither Report — Feedback & Triage

**Scope**: `src/` — mocks and tests excluded via `--filter-paths`
**Tool**: [Slither](https://github.com/crytic/slither) `0.11.5` static analysis
**Date reviewed**: 2026-07-08

**Command**

```bash
slither . --checklist \
  --filter-paths "node_modules,submodules,test,forge-std,mocks" \
  > doc/slither-report.md
```

---

## Summary

| ID | Detector | Severity | Instances | Disposition |
|----|----------|----------|-----------|-------------|
| ID-0 | `pragma` (multiple versions) | Informational | 1 | **By design (dependency-driven)** |
| ID-1..4 | `solc-version` (constraints w/ known issues) | Informational | 4 | **By design (dependency-driven)** |

Tally: **0 High · 0 Medium · 0 Low · 5 Informational** (5 results; 15 contracts analyzed).

---

## Informational Issues

### ID-0 — `pragma` (4 different Solidity versions used)

**Disposition: By design (dependency-driven)**

Slither reports four constraints: `^0.8.20`, `>=0.8.4`, `>=0.4.16`, `>=0.6.2`. All except `^0.8.20` originate from OpenZeppelin library files (`IERC20`, `IERC165`, `IERC20Metadata`, `draft-IERC6093`) that are not first-party code. Every `src/` file authored here uniformly uses `^0.8.20`. The actual compiler is pinned to `0.8.34` in `foundry.toml`.

**No action required.**

### ID-1..4 — `solc-version` (constraints contain known severe issues)

**Disposition: By design (dependency-driven)**

Informational warnings that the version *constraints* (`>=0.6.2`, `^0.8.20`, `>=0.8.4`, `>=0.4.16`) span compiler releases with historical bugs. The listed bugs do not affect the code as compiled, because the build pins `solc = "0.8.34"` — a release that post-dates and is unaffected by every cited issue. The wide floors again come from OZ dependency headers.

**No action required.**

---

## Executive triage

**Nothing to fix.** There are no High, Medium, or Low findings. The only results are Informational notes driven entirely by the pragma floors of imported OpenZeppelin dependencies, neutralized by the pinned `0.8.34` compiler. The previously-flagged constructor-parameter shadowing has been resolved. No result is exploitable.

# NAVI-Smart-Contract
Core Move packages for the NAVI Protocol, including the on-chain modules that power NAVI’s lending and related core features.

# 📚 Import Dependency

```bash
mvr add @navi-protocol/lending --network mainnet
```

# 📦 Build and test a package

```bash
sui move build -p ${PackageDir}
sui move test  -p ${PackageDir}
```

# ⚡ Publish and upgrade

These packages use Move's current package format: on-chain addresses live in each package's
`Published.toml` (keyed by environment) rather than in `Move.toml`, and dependency revisions are
pinned in `Move.lock`. A successful `publish` or `upgrade` writes the resulting package ID and
version back into `Published.toml`, so that file should be committed afterwards.

```bash
# first publication of a package
sui client publish ${PackageDir}

# subsequent upgrades
sui client upgrade -c ${UpgradeCapId} ${PackageDir}

# preview without submitting
sui client upgrade -c ${UpgradeCapId} --dry-run ${PackageDir}
```

`--gas-budget` is optional; without it the CLI estimates the budget from a dry run.

Two flags matter for these packages:

- `--with-unpublished-dependencies` publishes local dependencies that have no on-chain address
  yet, folding their modules into the package being published. `lending_core` v26 was released
  this way — see the verification note below.
- `--skip-dependency-verification` skips the check that each dependency's source compiles to its
  on-chain bytecode. It makes publishing faster but removes a real safety check, so use it only
  when the failure is understood.

# 🆘 Bug Bounty Program
https://hackenproof.com/companies/navi-protocol

# 📊 Version Status

| Package | Version | Package ID | Document | Audit |
|---|---|---|---|---|
| lending_core | 26 (latest) | `0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a` | [Preview](https://naviprotocol.gitbook.io/navi-protocol-developer-docs/smart-contract-overview/release-history/navi-lending-protocol-upgrade-announcement-2025-11-17) | ✅ [OtterSec](https://github.com/naviprotocol/navi-smart-contracts/blob/main/audits/NAVI_Pool_Increment_Audit_OtterSec_2025.pdf) |
| oracle | 5 (latest) | `0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea` | — | ✅ [MoveBit](https://github.com/naviprotocol/navi-smart-contracts/blob/main/audits/NAVI_Oracle_PythPro_Increment_Audit_MoveBit_2026.pdf) |

Package IDs above are the current `published-at` values on Sui mainnet; the corresponding
`original-id` for each package is recorded in its `Published.toml`.

# 🔍 Notes on source verification and tests

- `sui client verify-source` succeeds for `oracle`. For `lending_core` it reports a mismatch on
  10 modules. The difference is confined to the ordering of the module `use` table: `lending_core`
  v26 was published with its `ray_math`, `safe_math` and `utils` modules supplied as separate
  unpublished packages and folded into the package at publish time, a layout `verify-source`
  cannot reproduce. The compiled logic is identical — the remaining 11 modules verify byte for
  byte. This repository keeps the three modules inside `lending_core/sources`, so a future
  release published from this layout will verify cleanly.
- The test suites in this repository (`sui move test` — 148 tests for `lending_core`, 95 for
  `oracle`) are the ones we run in CI against the published sources. They are not a mirror of the
  full internal suite: several older incentive and integration test files were dropped when
  `math` and `utils` were merged into `lending_core`, and internal tests that depend on
  non-public fixtures are not published here.

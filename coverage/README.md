# Test coverage: lending_core v26 and oracle v5

Coverage of the deployed versions of `lending_core` (v26, `0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a`) and `oracle` (v5, `0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea`), measured on their source with our internal test suite: 819 tests (lending_core 724, oracle 95), all passing. The internal suite is broader than the tests published in this repository; we will publish the full test suites with the next release.

Measured with `sui move test --coverage -e mainnet` (Sui CLI 1.81.1) on commit `ad22c84` of our internal development repository, the source of the deployed versions.

## Results

| Package | Instructions | Lines | Branches |
|---|---:|---:|---:|
| `lending_core` v26 | **97.17%** (12,929 / 13,305) | **99.15%** (3,379 / 3,408) | **89.41%** (1,030 / 1,152) |
| `oracle` v5 | **96.14%** (1,944 / 2,022) | **99.46%** (552 / 555) | **91.23%** (208 / 228) |

## Counting basis

The figures count the code that runs in the protocol and that unit tests can exercise. Not counted:

- Entry points retired from use and kept only because a package upgrade must keep every public signature; their body is a single `abort`.
- Version-migration functions, which run once after an upgrade; `sui move test` cannot perform a package upgrade.
- Code that takes no part in protocol runtime logic: functions that nothing in the protocol calls, such as unused helpers, event emitters and getters, read-only price helpers, and the publish-time initialiser.
- The Supra price read, which needs a Supra object that unit tests cannot construct, and the code reachable only through it. Its validation logic is tested through test-only versions with mocked prices.
- `#[test_only]` helpers in `sources/`, which are not part of the published bytecode.

Every function, counted or not, is listed with its reason in [`lending_core-v26-functions.csv`](lending_core-v26-functions.csv) and [`oracle-v5-functions.csv`](oracle-v5-functions.csv).

## Per module

| Package | Module | Instructions | Lines | Branches |
|---|---|---:|---:|---:|
| `lending_core` | `account` | 100.00% | 100.00% | 66.67% |
| `lending_core` | `calculator` | 98.97% | 100.00% | 94.74% |
| `lending_core` | `constants` | 100.00% | 100.00% | - |
| `lending_core` | `dynamic_calculator` | 97.30% | 98.96% | 95.92% |
| `lending_core` | `error` | 100.00% | 100.00% | - |
| `lending_core` | `event` | 100.00% | 100.00% | - |
| `lending_core` | `flash_loan` | 88.97% | 99.39% | 80.70% |
| `lending_core` | `incentive` | 93.10% | 96.34% | 71.96% |
| `lending_core` | `incentive_v2` | 97.77% | 99.67% | 91.89% |
| `lending_core` | `incentive_v3` | 98.43% | 98.59% | 91.98% |
| `lending_core` | `lending` | 100.00% | 100.00% | 100.00% |
| `lending_core` | `logic` | 98.88% | 100.00% | 92.75% |
| `lending_core` | `manage` | 93.31% | 98.95% | 86.67% |
| `lending_core` | `pool` | 95.16% | 96.91% | 86.67% |
| `lending_core` | `pool_manager` | 97.48% | 98.35% | 86.79% |
| `lending_core` | `storage` | 98.07% | 100.00% | 93.38% |
| `lending_core` | `validation` | 89.92% | 100.00% | 84.44% |
| `lending_core` | `version` | 100.00% | 100.00% | 100.00% |
| `oracle` | `adaptor_supra` | 100.00% | 100.00% | - |
| `oracle` | `config` | 96.90% | 100.00% | 90.98% |
| `oracle` | `oracle` | 88.70% | 100.00% | 82.50% |
| `oracle` | `oracle_constants` | 100.00% | 100.00% | - |
| `oracle` | `oracle_error` | 78.57% | 78.57% | - |
| `oracle` | `oracle_manage` | 100.00% | 100.00% | - |
| `oracle` | `oracle_provider` | 100.00% | 100.00% | - |
| `oracle` | `oracle_utils` | 100.00% | 100.00% | 100.00% |
| `oracle` | `oracle_version` | 100.00% | 100.00% | 100.00% |
| `oracle` | `strategy` | 97.62% | 100.00% | 91.67% |

## Method

- Instructions: `sui move coverage summary --test -e mainnet --summarize-functions` over the union of the coverage maps of both test packages; a bytecode instruction counts as covered if any test executes it.
- Lines: the executable lines of each counted function, from the compiler source maps; a line counts as covered if any instruction starting on it is executed.
- Branches: `BRDA` edges from `sui move coverage lcov`, assigned to the function that contains them; an edge counts as covered if any test takes it.

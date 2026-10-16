# Test coverage: lending_core v26 and oracle v5

This folder holds the native coverage maps written by `sui move test --coverage -e mainnet` (Sui CLI 1.81.1) when our internal test suite runs against the source of the deployed versions (commit `ad22c84` of our internal development repository):

| File | Package | Tests |
|---|---|---:|
| `lending_core-v26.mvcov` | `lending_core` v26 (`0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a`) | 724, all passing |
| `oracle-v5.mvcov` | `oracle` v5 (`0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea`) | 95, all passing |

The full test suites will be published with the next release.

## Current coverage

| Package | Instructions | Lines | Branches |
|---|---:|---:|---:|
| `lending_core` v26 | 97.17% | 99.15% | 89.41% |
| `oracle` v5 | 96.14% | 99.46% | 91.23% |

Instructions are from `sui move coverage summary`, lines from the compiler source maps, and branches from `sui move coverage lcov`, over the union of the two maps.

## Counting basis

The figures count the code that runs in the protocol and that unit tests can exercise. Not counted:

- Entry points retired from use and kept only because a package upgrade must keep every public signature; their body is a single `abort`.
- Version-migration functions, which run once after an upgrade; `sui move test` cannot perform a package upgrade.
- Code that takes no part in protocol runtime logic: functions that nothing in the protocol calls, such as unused helpers, event emitters and getters, read-only price helpers, and the publish-time initialiser.
- The Supra price read, which needs a Supra object that unit tests cannot construct, and the code reachable only through it. Its validation logic is tested through test-only versions with mocked prices.
- `#[test_only]` helpers in `sources/`, which are not part of the published bytecode.

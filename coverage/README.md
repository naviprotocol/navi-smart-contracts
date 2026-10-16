# Test coverage maps: lending_core v26 and oracle v5

Native coverage maps written by `sui move test --coverage -e mainnet` (Sui CLI 1.81.1) when our internal test suite runs against the source of the deployed versions (commit `ad22c84` of our internal development repository):

| File | Package | Tests |
|---|---|---:|
| `lending_core-v26.mvcov` | `lending_core` v26 (`0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a`) | 724, all passing |
| `oracle-v5.mvcov` | `oracle` v5 (`0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea`) | 95, all passing |

Each file is the package's `.coverage_map.mvcov`, with the executed instructions recorded per test. The full test suites will be published with the next release.

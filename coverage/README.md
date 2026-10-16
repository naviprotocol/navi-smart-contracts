# Test coverage: lending_core and oracle

`lending_core.mvcov` and `oracle.mvcov` are the native coverage maps written by `sui move test --coverage -e mainnet` (Sui CLI 1.81.1) when our internal test suite runs against the source of the deployed packages. Each map records, test by test, the bytecode instructions that the test executed.

## Current coverage

| Package | Tests | Instructions | Lines | Branches |
|---|---:|---:|---:|---:|
| `lending_core` | 724, all passing | 97.17% | 99.15% | 89.41% |
| `oracle` | 95, all passing | 96.14% | 99.46% | 91.23% |

## Counting basis

**How coverage is measured.** All tests of both packages are combined: an instruction, line or branch is covered if at least one test executes it.

- Instructions: from `sui move coverage summary`, instructions executed over instructions counted.
- Lines: the executable lines of the counted functions, meaning every line on which a bytecode instruction starts, taken from the compiler source maps. A line is covered if one of those instructions is executed.
- Branches: the outgoing edges of each conditional, from `sui move coverage lcov`. A branch is covered if a test takes that edge.

**What is counted.** The code that runs in the protocol and that unit tests can exercise: every function compiled from the packages' `sources/`, except the following.

1. Retired entry points. A package upgrade must keep every public signature, so entry points taken out of use stay in the package with a body of a single `abort`.
2. Version-migration functions. They run once after an upgrade, and `sui move test` cannot perform a package upgrade.
3. Code that takes no part in protocol runtime logic: functions that nothing in the protocol calls, such as unused helpers, event emitters and getters, read-only price helpers, and the publish-time initialiser.
4. The Supra price read and the code reachable only through it. It needs a Supra object that unit tests cannot construct; its validation logic is tested through test-only versions with mocked prices.
5. `#[test_only]` helpers in `sources/`, which are not part of the published bytecode.

## Tests not yet published

The maps record 724 `lending_core` tests and 95 `oracle` tests. 576 of the `lending_core` tests, in 40 of its 52 test modules, are not yet in this repository: for example `liquidation_borrow_fee_test` (41 tests), `pool_manager_test` (37), `isolated_market_tests` (36), `sup_logic_test` (33), `incentive_v3_test_target` (32) and `emode_tests_v2` (30). Each test is recorded in the map under its own name, so the full list can be read from the file:

```sh
strings lending_core.mvcov | grep '\.json\.zst$'
```

We will publish the full test suites in this repository.

# NAVI Protocol Security Audits

This directory contains all security audit reports for the NAVI Protocol. The audits have been conducted by multiple reputable security firms to ensure the safety and reliability of the protocol.

## Audit Reports

### 2023 Audits

#### Full Protocol Audits
- **Movebit - June 2023**: `NAVI_Full_Audit_Movebit_2023.pdf`
  - Comprehensive security audit of the NAVI protocol
  - Covers core lending functionality and smart contract security
  - Contract version: `lending_core` v1, `oracle` v1

- **OtterSec - 2023**: `NAVI_Full_Audit_OtterSec_2023.pdf`
  - Full protocol security assessment
  - Focus on smart contract vulnerabilities and economic security
  - Contract version: `lending_core` v1, `oracle` v1

- **Salus - 2023**: `NAVI_Penetration_Test_Salus_2023.pdf`
  - Penetration testing and security assessment
  - Real-world attack simulation and vulnerability testing

### 2024 Audits

#### Full Protocol Audits
- **Veridise - 2024**: `NAVI_Full_Audit_Veridise_2024.pdf`
  - Comprehensive security review of the entire protocol
  - Advanced formal verification techniques
  - Contract version: `lending_core` v16

#### Incremental Audits
- **OtterSec - 2024**: `NAVI_Increment_Audit_OtterSec_2024.pdf`
  - Incremental security audit for protocol updates
  - Focus on new features and modifications
  - Contract version: `lending_core` v14

- **Veridise - 2024**: `NAVI_Oracle_Increment_Audit_Veridise_2024.pdf`
  - Oracle system security audit
  - Focus on price feed security and oracle manipulation resistance
  - Contract version: `oracle` v3

### 2025 Audits

From 2025 on, each report below lists the commit it audited. Audits are run on our internal development
repository, which carries the same code as this repository but whose development history is not public, so the
commits refer to that repository. Security reviewers can request read access to verify a commit against the code here.

#### Full Protocol Audits
- **OtterSec - 2025**: `NAVI_Full_Audit_OtterSec_2025.pdf`
  - Latest comprehensive security assessment
  - Updated security analysis for current protocol version
  - Audited commit: `6ae8e49`
  - Contract version: `lending_core` v22, `oracle` v3

#### Incremental Audits
- **Movebit - 2025**: `NAVI_Incentive_Increment_Audit_Movebit_2025.pdf`
  - Incentive mechanism security audit
  - Focus on reward distribution and economic security
  - Audited commits: `d46b85f` (initial), `dd8d847` (final)
  - Contract version: `lending_core` v22

- **OtterSec - 2025**: `NAVI_Pool_Increment_Audit_OtterSec_2025.pdf`
  - Incremental audit of the pool layer
  - Focus on pool accounting and the staking-backed SUI pool manager
  - Audited commit: `f8f6118`
  - Contract version: `lending_core` v23, `liquid_staking` v1

### 2026 Audits

#### Incremental Audits
- **MoveBit - 2026**: `NAVI_EMode_Increment_Audit_MoveBit_2026.pdf`
  - Incremental audit of the efficiency mode (E-Mode) feature
  - Focus on E-Mode LTV/liquidation parameters and user state transitions
  - Audited changes between `2954d3b` and `bc86742`; fixes reviewed up to `61d4292`
  - Contract version: `lending_core` v24, `oracle` v4

- **Veridise - 2026**: `NAVI_EMode_Increment_Audit_Veridise_2026.pdf`
  - Independent incremental audit of the same E-Mode release
  - Audited commit: `bc86742`
  - Contract version: `lending_core` v24, `oracle` v4

- **MoveBit - 2026**: `NAVI_Oracle_PythPro_Increment_Audit_MoveBit_2026.pdf`
  - Incremental audit of the migration from the legacy Pyth integration to the
    `pyth_pro_compatible` oracle stack
  - Focus on the v2/v3 oracle read and price-update paths, deprecation stubs kept for
    upgrade compatibility, and the related package and version configuration changes
  - Audited changes between `762f00a` and `eab7a4e`
  - Contract version: `lending_core` v26, `oracle` v5

#### Formal Verification
- **Asymptotic - 2026**: `NAVI_Formal_Verification_Asymptotic_2026.pdf`
  - Formal verification of the lending core, oracle stack, incentives, E-Mode and the
    arithmetic kernel with the Sui Prover (500+ passing specifications)
  - Covers fund conservation, frame isolation, round-trip exactness, protocol gating, and
    the exact rounding boundaries where intended invariants stop holding
  - Verified revision: `96fa224`
  - Contract version: `lending_core` v26, `oracle` v5

## Contract Versions

Contract versions above are the on-chain package versions on Sui mainnet that contain the audited code.

| Package | Version | Package ID |
|---|---|---|
| `lending_core` | v1 | `0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca` |
| `lending_core` | v14 | `0x06007a2d0ddd3ef4844c6d19c83f71475d6d3ac2d139188d6b62c052e6965edd` |
| `lending_core` | v16 | `0x7c9b90b3fda0fa4aa8ee88ae6c4a0b83c773f74936b5354448cb94662e94442d` |
| `lending_core` | v22 | `0x81c408448d0d57b3e371ea94de1d40bf852784d3e225de1e74acab3e8395c18f` |
| `lending_core` | v23 | `0xee0041239b89564ce870a7dec5ddc5d114367ab94a1137e90aa0633cb76518e0` |
| `lending_core` | v24 | `0x1e4a13a0494d5facdbe8473e74127b838c2d446ecec0ce262e2eddafa77259cb` |
| `lending_core` | v26 | `0x512f28261c1a293f49416d8885b8d5d32bde6dd68a99a0be36fe42b248e6833a` |
| `oracle` | v1 | `0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f` |
| `oracle` | v3 | `0xc2d49bf5e75d2258ee5563efa527feb6155de7ac6f6bf025a23ee88cd12d5a83` |
| `oracle` | v4 | `0x203728f46eb10d19f8f8081db849c86aa8f2a19341b7fd84d7a0e74f053f6242` |
| `oracle` | v5 | `0x4837ae94425107554c8847721cf9954c1ad8e10520433b9e37dc11c507148bea` |
| `liquid_staking` | v1 | `0x634511c660964940915acb37dde75963e35f2d1b0a034b41e2da8f3e9d1491ae` |

## Audit Coverage

The audits cover the following key areas:

- **Core Lending Protocol**: Smart contract security for lending and borrowing functionality
- **Oracle System**: Price feed security and manipulation resistance
- **Incentive Mechanisms**: Reward distribution and economic security
- **Flash Loans**: Security of flash loan functionality
- **Liquidation System**: Automated liquidation mechanism security
- **Access Control**: Permission and role-based security
- **Economic Security**: Tokenomics and incentive alignment

## Security Firms

The following reputable security firms have conducted audits:

- **Movebit**: Specialized in Move language security and Sui blockchain audits
- **OtterSec**: Blockchain security experts with focus on DeFi protocols
- **Veridise**: Advanced formal verification and security analysis
- **Salus**: Penetration testing and real-world security assessment
- **Asymptotic**: Formal verification of Move contracts with the Sui Prover

## Contact

For questions about security audits or to report security issues, please contact the NAVI Protocol team through official channels.

---

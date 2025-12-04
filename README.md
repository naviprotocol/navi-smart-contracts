# protocol-core 

# Import Dependency

```bash
mvr add @navi-protocol/lending --network mainnet
```

# Build the package

```bash
sui move build -p `pwd`/${PackageDir}
```

# Publish Move modules

```bash
sui client publish --gas-budget 100000000 ${PackageDir}
sui client publish --gas-budget 100000000 --skip-dependency-verification ${PackageDir}
sui client upgrade --gas-budget 100000000 --upgrade-capability ${upgradeCap}
```

# Bug Bounty Program
https://hackenproof.com/companies/navi-protocol

## Upgrade Status

| Package | Version | Document |
|---|---|---|
| lending_core | 23(latest) | [Preview](https://app.gitbook.com/o/dcxQ7e5pivSbceCjCqQ8/s/WcKfs3vWiDuhitgCkBQQ/smart-contract-overview/release-history/navi-lending-protocol-upgrade-announcement-2025-11-17) |

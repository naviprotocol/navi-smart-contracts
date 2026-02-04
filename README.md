# NAVI-Smart-Contract
Core Move packages for the NAVI Protocol, including the on-chain modules that power NAVI’s lending and related core features.

# 📚 Import Dependency

```bash
mvr add @navi-protocol/lending --network mainnet
```

# 📦 Build the package

```bash
sui move build -p `pwd`/${PackageDir}
```

# ⚡ Publish Move modules

```bash
sui client publish --gas-budget 100000000 ${PackageDir}
sui client publish --gas-budget 100000000 --skip-dependency-verification ${PackageDir}
sui client upgrade --gas-budget 100000000 --upgrade-capability ${upgradeCap}
```

# 🆘 Bug Bounty Program
https://hackenproof.com/companies/navi-protocol

# 📊 Version Status

| Package | Version | Document | Audit | 
|---|---|---|---|
| lending_core | 23(latest) | [Preview](https://naviprotocol.gitbook.io/navi-protocol-developer-docs/smart-contract-overview/release-history/navi-lending-protocol-upgrade-announcement-2025-11-17) | ✅ [OtterSec](https://github.com/naviprotocol/navi-smart-contracts/blob/main/audits/NAVI_Pool_Increment_Audit_OtterSec_2025.pdf) |

# protocol-core (Commit Locked)

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

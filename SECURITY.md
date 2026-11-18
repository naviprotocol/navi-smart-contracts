# Security policy

## Reporting a vulnerability

Please report security issues in the NAVI Protocol smart contracts through our bug bounty programme on
HackenProof: https://hackenproof.com/programs/navi-protocol

The programme publishes the reward tiers, the triage and response SLA, and the disclosure
guidelines that apply to every report.

Security contact: Bounty Team — bounty@naviprotocol.io

For an urgent issue, or one outside the programme's scope, email bounty@naviprotocol.io directly.

Do not open a public GitHub issue for a vulnerability.

## Scope

The packages in this repository as deployed on Sui mainnet. Each package's `Published.toml` records
its deployed package id and version.

## Coordinated disclosure

We triage every report within 72 hours. Once the fix for a reported issue is live on chain, the
reporter may publish the report 30 days later, with exploit details redacted while the affected code
is still in use. We acknowledge valid reports through the programme and credit reporters there unless
they prefer otherwise.

## Incident disclosure

If a security incident materially affects user funds, protocol solvency or access control, we disclose it
publicly through our official channels within 72 hours of confirming it, and publish a written post-mortem
within 14 days covering the timeline, root cause, remediation and follow-ups.

## SEAL Safe Harbor

NAVI has adopted the SEAL Whitehat Safe Harbor Agreement. During an active exploit of the in-scope contracts,
eligible whitehats may rescue funds at risk, return them to NAVI's asset recovery address and receive a bounty.
Our agreement is `0x4B52EF18651509BC0e3d0Fe4a847A97271C30C7a` on Ethereum mainnet, registered in the SEAL
SafeHarborRegistry by NAVI's MPC wallet `0x55cF0D54961c1E8A83a885bfA58Ba169032A1015`.

Scope, asset recovery address, bounty terms and whitehat requirements: [SAFE_HARBOR.md](SAFE_HARBOR.md).
Contact bounty@naviprotocol.io before returning funds or claiming a bounty.

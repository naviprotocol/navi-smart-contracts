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

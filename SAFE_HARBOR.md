# SEAL Safe Harbor

> **Read this first.**
> 1. **Check the agreement address.** NAVI's Safe Harbor agreement is
>    `0x4B52EF18651509BC0e3d0Fe4a847A97271C30C7a` on Ethereum mainnet, and it is valid only because this address is
>    published on both of NAVI's official channels: NAVI's GitHub (https://github.com/naviprotocol) and NAVI's GitBook
>    (https://naviprotocol.gitbook.io). Any other agreement or registration that names NAVI is not ours.
> 2. **Contact NAVI before you return funds or claim a bounty.** Reach NAVI at bounty@naviprotocol.io and confirm the
>    asset recovery address with us. NAVI strongly advises you not to act on your own.

NAVI Protocol has adopted the SEAL Safe Harbor Agreement for Whitehats. During an active exploit of the contracts in
scope below, eligible whitehats may rescue funds at risk, return them to the asset recovery address, and receive the
bounty set out below. The agreement does not cover any action that starts an exploit, and it does not replace our bug
bounty program: vulnerabilities found outside an active exploit go to https://hackenproof.com/programs/navi-protocol.

- Agreement text: SEAL Whitehat Safe Harbor Agreement v3.0.0,
  https://bafkreiernns2f4nv2uzvwtzjc2jboyivsu2mixz33y3xo7cvtllsuao6jy.ipfs.w3s.link
- Adopted on: 16 November 2026
- Agreement contract (Ethereum mainnet): `0x4B52EF18651509BC0e3d0Fe4a847A97271C30C7a`,
  https://etherscan.io/address/0x4B52EF18651509BC0e3d0Fe4a847A97271C30C7a
- Registry: SEAL SafeHarborRegistry `0x326733493E143b8904716E7A64A9f4fb6A185a2c` (Ethereum mainnet)
- Adopted and owned by NAVI's MPC wallet: `0x55cF0D54961c1E8A83a885bfA58Ba169032A1015`
- Agreement created: https://etherscan.io/tx/0xb439cc53a7c75bb813f51f8b1f1a606f3aa0ec755f9dcbc7fdfe001fb97a5e6d
- Registration: https://etherscan.io/tx/0x55475d87c7b1308ae2bd0289333f4cda35591eee4bb603f07e69dc0844e15555

## Scope

Chain: Sui mainnet (`sui:mainnet`).

| Account | What it is | Child contract scope |
|---|---|---|
| `0xd899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca` | `lending_core` package (original id; every version), including the market `Storage` objects and the `Pool` objects that hold user deposits | All |
| `0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f` | `oracle` package (original id; every version), including the `PriceOracle` and `OracleConfig` objects | All |

"All" covers the listed package and everything it creates, now and in future, so new markets and pools are in scope
without an update.

## Asset recovery address

The asset recovery address is the holder of the `lending_core` UpgradeCap
`0xdba1b40f3537441b51d2848fc0a149610e48e67c1cc48c6ad641767622000623`, NAVI's 3-of-5 multisig on Sui mainnet:

- `0x25549f15b144032b4a61921552f6ecbfea13556615f7b45576b12f10d67955e7`

Anyone can check this on chain: the owner of the UpgradeCap object above is this address. Before sending anything,
confirm the address with NAVI at the contact below.

Return all rescued funds to the asset recovery address as promptly as reasonably practicable. If you cannot do so
within six hours of taking control of them, notify NAVI that you still intend to return them and why you cannot yet.

## Security contact

- Email: bounty@naviprotocol.io

Notify NAVI that you are attempting a rescue as soon as reasonably practicable, before you start if doing so would not
put the rescue at risk, and in any case before you return funds or claim a bounty.

## Bounty terms

| Term | Value |
|---|---|
| Bounty | 10% of the funds recovered |
| Cap per whitehat | $300,000, the maximum of our bug bounty program |
| Aggregate cap per incident | $300,000, shared pro rata when several whitehats take part |
| Retainable | No: the whitehat returns all funds and NAVI pays the bounty afterwards |
| Identity | Named: the whitehat completes KYC before payout |
| Diligence | Before payout, the whitehat is screened against the sanctions lists of the US, the UK and the EU |

The bounty for a whitehat is `min(10% x amount recovered, $300,000)`, scaled down pro rata if the total for the incident
would exceed $300,000.

The same requirements (official addresses, recovery address, contact before acting) are recorded in the agreement's
on-chain diligence requirements.

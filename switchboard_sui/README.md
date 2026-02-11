<div align="center">
  <a href="#">
    <img src="https://github.com/switchboard-xyz/sbv2-core/raw/main/website/static/img/icons/switchboard/avatar.png" />
  </a>

  <h1>Switchboard On-Demand on Sui</h1>

  <p>Switchboard is a multi-chain, permissionless oracle protocol allowing developers to fully control how data is relayed on-chain to their smart contracts.</p>

  <div>
    <a href="https://discord.gg/switchboardxyz">
      <img alt="Discord" src="https://img.shields.io/discord/841525135311634443?color=blueviolet&logo=discord&logoColor=white" />
    </a>
    <a href="https://twitter.com/switchboardxyz">
      <img alt="Twitter" src="https://img.shields.io/twitter/follow/switchboardxyz?label=Follow+Switchboard" />
    </a>
  </div>

  <h4>
    <strong>Documentation: </strong><a href="https://docs.switchboard.xyz">docs.switchboard.xyz</a>
  </h4>
</div>

## Active Deployments

The Switchboard On-Demand service is currently deployed on the following networks:

- Mainnet: [0xe6717fb7c9d44706bf8ce8a651e25c0a7902d32cb0ff40c0976251ce8ac25655](https://suiscan.xyz/mainnet/object/0xe6717fb7c9d44706bf8ce8a651e25c0a7902d32cb0ff40c0976251ce8ac25655)
- Testnet: [0x578b91ec9dcc505439b2f0ec761c23ad2c533a1c23b0467f6c4ae3d9686709f6](https://suiscan.xyz/testnet/object/0x578b91ec9dcc505439b2f0ec761c23ad2c533a1c23b0467f6c4ae3d9686709f6)

## Typescript-SDK Installation

To use Switchboard On-Demand, add the following dependencies to your project:

### NPM

```bash
npm install @switchboard-xyz/sui-sdk --save
```

### Bun

```bash
bun add @switchboard-xyz/sui-sdk
```

### PNPM

```bash
pnpm add @switchboard-xyz/sui-sdk
```

## Creating an Aggregator and Sending Transactions

Building a feed in Switchboard can be done using the Typescript SDK, or it can be done with the [Switchboard Web App](https://ondemand.switchboard.xyz/sui/mainnet). Visit our [docs](https://docs.switchboard.xyz/docs) for more on designing and creating feeds.

### Building Feeds

```typescript
import {
  CrossbarClient,
  SwitchboardClient,
  Aggregator,
  ON_DEMAND_MAINNET_QUEUE,
  ON_DEMAND_TESTNET_QUEUE,
} from "@switchboard-xyz/sui-sdk";

// for initial testing and development, you can use the public
// https://crossbar.switchboard.xyz instance of crossbar
const crossbar = new CrossbarClient("https://crossbar.switchboard.xyz");

// ... define some jobs ...

const queue = isMainnetSui ? ON_DEMAND_MAINNET_QUEUE : ON_DEMAND_TESTNET_QUEUE;

// Store some job definition
const { feedHash } = await crossbarClient.store(queue.toBase58(), jobs);

// Create a SwitchboardClient using the SuiClient configured with your favorite RPC on testnet or mainnet
const sb = new SwitchboardClient(suiClient);

// try creating a feed
const feedName = "BTC/USDT";

// Require only one oracle response needed
const minSampleSize = 1;

// Allow update data to be up to 60 seconds old
const maxStalenessSeconds = 60;

// If jobs diverge more than 1%, don't allow the feed to produce a valid update
const maxVariance = 1e9;

// Require only 1 job response
const minJobResponses = 1;

//==========================================================
// Feed Initialization On-Chain
//==========================================================

let transaction = new Transaction();

// add the tx to the PTB
await Aggregator.initTx(sb, transaction, {
  feedHash,
  name: feedName,
  authority: userAddress,
  minSampleSize,
  maxStalenessSeconds,
  maxVariance,
  minResponses: minJobResponses,
});

// Send the transaction
const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction,
  options: {
    showEffects: true,
  },
});

// Capture the created aggregator ID
let aggregatorId;
res.effects?.created?.forEach((c) => {
  if (c.reference.objectId) {
    aggregatorId = c.reference.objectId;
  }
});

// Wait for transaction confirmation
await client.waitForTransaction({
  digest: res.digest,
});

// Log the transaction effects
console.log(res);
```

## Updating Feeds

With Switchboard On-Demand, passing the PTB into the feed update method handles the update automatically.

```typescript
const aggregator = new Aggregator(sb, aggregatorId);

// Create the PTB transaction
let feedTx = new Transaction();

// Fetch and log the oracle responses
const response = await aggregator.fetchUpdateTx(feedTx);
console.log("Fetch Update Oracle Response: ", response);

// Send the transaction
const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: feedTx,
  options: {
    showEffects: true,
  },
});

// Wait for transaction confirmation
await client.waitForTransaction({
  digest: res.digest,
});

// Log the transaction effects
console.log({ aggregatorId, res });
```

Note: Ensure the Switchboard Aggregator update is the first action in your PTB or occurs before referencing the feed update.

## Adding Switchboard to Move Code

To integrate Switchboard with Move, add the following dependencies to Move.toml:

```toml
[dependencies.Switchboard]
git = "https://github.com/switchboard-xyz/sui.git"
subdir = "on_demand/"
rev = "mainnet" # testnet or mainnet

[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
rev = "framework/mainnet" # testnet or mainnet
# override = true # Uncomment if you need to override the Sui dependency
```

Once dependencies are configured, updated aggregators can be referenced easily.

## Example Move Code for Using Switchboard Values

In the example.move module, use the Aggregator and CurrentResult types to access the latest feed data.

```move
module example::switchboard;

use switchboard::aggregator::{Aggregator, CurrentResult};
use switchboard::decimal::Decimal;

public entry fun use_switchboard_value(aggregator: &Aggregator) {

    // Get the latest update info for the feed
    let current_result = aggregator.current_result();

    // Access various result properties
    let result: Decimal = current_result.result();        // Median result
    let result_u128: u128 = result.value();               // Result as u128
    let min_timestamp_ms: u64 = current_result.min_timestamp_ms(); // Oldest data timestamp
    let max_timestamp_ms: u64 = current_result.max_timestamp_ms(); // Latest data timestamp
    let range: Decimal = current_result.range();          // Range of results
    let mean: Decimal = current_result.mean();            // Average (mean)
    let stdev: Decimal = current_result.stdev();          // Standard deviation
    let max_result: Decimal = current_result.max_result();// Max result
    let min_result: Decimal = current_result.min_result();// Min result
    let neg: bool = result.neg();                         // Check if negative (ignore for prices)

    // Use the computed result as needed...
}
```

This implementation allows you to read and utilize Switchboard data feeds within Move. If you have any questions or need further assistance, please contact the Switchboard team.

**DISCLAIMER: ORACLE CODE AND CORE LOGIC ARE AUDITED - THE AUDIT FOR THIS ON-CHAIN ADAPTER IS PENDING**

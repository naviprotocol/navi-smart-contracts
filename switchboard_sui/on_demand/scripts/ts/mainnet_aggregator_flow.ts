// sui client upgrade --upgrade-capability 0xda0d1de2ce8afde226f66b1963c3f6afc929ab49eaeed951c723a481499e31e9
import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 as fromB64, toHex, fromHex } from "@mysten/sui/utils";
import {
  Oracle,
  Queue,
  State,
  Aggregator,
  ON_DEMAND_MAINNET_STATE_OBJECT_ID,
  SwitchboardClient,
  ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID,
} from "@switchboard-xyz/sui-sdk";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import {
  getDefaultGuardianQueue,
  Oracle as SolanaOracle,
} from "@switchboard-xyz/on-demand";

const MAINNET_SUI_RPC = "https://fullnode.mainnet.sui.io:443";
const client = new SuiClient({
  url: MAINNET_SUI_RPC,
});
const sb = new SwitchboardClient(client);

let keypair: Ed25519Keypair | null = null;

try {
  // Read the keystore file (usually in JSON format)
  const keystorePath = path.join(
    os.homedir(),
    ".sui",
    "sui_config",
    "sui.keystore"
  );
  const keystore = JSON.parse(fs.readFileSync(keystorePath, "utf-8"));

  // Ensure the keystore has at least 4 keys
  if (keystore.length < 4) {
    throw new Error("Keystore has fewer than 4 keys.");
  }

  // Access the 4th key (index 3) and decode from base64
  const secretKey = fromB64(keystore[3]);
  keypair = Ed25519Keypair.fromSecretKey(secretKey.slice(1)); // Slice to remove the first byte if needed
} catch (error) {
  console.log("Error:", error);
}

if (!keypair) {
  throw new Error("Keypair not loaded");
}

//================================================================================================
// Initialization and Logging
//================================================================================================

// create new user
const userAddress = keypair.getPublicKey().toSuiAddress();

console.log(`User account ${userAddress} loaded.`);

console.log("Initializing MAINNET Guardian Queue Setup");
const chainID = await client.getChainIdentifier();

console.log(`Chain ID: ${chainID}`);

const state = new State(sb, ON_DEMAND_MAINNET_STATE_OBJECT_ID);
const stateData = await state.loadData();

console.log("State Data: ", stateData);

const queue = new Queue(sb, stateData.guardianQueue);
console.log("Queue Data: ", await queue.loadData());

const switchboardObjectAddress = ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID;
const gql = new SuiGraphQLClient({
  url: "https://sui-mainnet.mystenlabs.com/graphql",
});

const allOracles = await queue.loadOracleData();
console.log("All Oracles: ", allOracles);

//================================================================================================
// Initialize Feed Flow
//================================================================================================

const aggregators = await Aggregator.loadAllFeeds(
  gql,
  switchboardObjectAddress
);

console.log(aggregators);

const ag = new Aggregator(sb, aggregators[3].id);
console.log("Aggregator Data: ", await ag.loadData());

// try creating a feed
const feedName = "BTC/USDT";

// BTC USDT
const feedHash =
  "0x013b9b2fb2bdd9e3610df0d7f3e31870a1517a683efb0be2f77a8382b4085833";
const minSampleSize = 1;
const maxStalenessSeconds = 60;
const maxVariance = 1e9;
const minResponses = 1;

let transaction = new Transaction();
await Aggregator.initTx(sb, transaction, {
  feedHash,
  name: feedName,
  authority: userAddress,
  minSampleSize,
  maxStalenessSeconds,
  maxVariance,
  minResponses,
  oracleQueueId: stateData.oracleQueue,
});
const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction,
  options: {
    showEffects: true,
  },
});
let aggregatorId;
res.effects?.created?.forEach((c) => {
  if (c.reference.objectId) {
    aggregatorId = c.reference.objectId;
  }
});

console.log("Aggregator init response:", res);

if (!aggregatorId) {
  throw new Error("Failed to create aggregator");
}

// wait for the transaction to be confirmed
await client.waitForTransaction({
  digest: res.digest,
});

const aggregator = new Aggregator(sb, aggregatorId);

console.log("Aggregator Data: ", await aggregator.loadData());

let feedTx = new Transaction();

const suiQueue = new Queue(sb, stateData.oracleQueue);
const suiQueueData = await suiQueue.loadData();

console.log("Sui Queue Data: ", suiQueueData);

const response = await aggregator.fetchUpdateTx(feedTx);

console.log("Fetch Update Response: ", response);

// send the transaction
const feedResponse = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: feedTx,
  options: {
    showEffects: true,
  },
});

console.log("Feed response:", feedResponse);

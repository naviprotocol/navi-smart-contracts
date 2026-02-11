// sui client upgrade --upgrade-capability 0x75c9afab64928bbb62039f0b4f4bb4437e5312557583c4f3d350affd705cb1ba
import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 as fromB64, toHex, fromHex } from "@mysten/sui/utils";
import {
  Oracle,
  Queue,
  State,
  ON_DEMAND_TESTNET_STATE_OBJECT_ID,
  ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID,
  SwitchboardClient,
} from "@switchboard-xyz/sui-sdk";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import {
  getDefaultGuardianQueue,
  ON_DEMAND_DEVNET_GUARDIAN_QUEUE,
  ON_DEMAND_DEVNET_QUEUE,
  Oracle as SolanaOracle,
} from "@switchboard-xyz/on-demand";

const TESTNET_SUI_RPC = "https://fullnode.testnet.sui.io:443";
const client = new SuiClient({
  url: TESTNET_SUI_RPC,
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

const adminCap =
  "0xc256f2b0a61af132f705a5a9d345edcc802fecba3213d6002265dfeb576ece90";

// create new user
const userAddress = keypair.getPublicKey().toSuiAddress();

console.log(`User account ${userAddress} loaded.`);

const guardianQueueInitTx = new Transaction();

// =================================================================================================
// Guardian Queue
// =================================================================================================

await Queue.initTx(sb, guardianQueueInitTx, {
  queueKey: ON_DEMAND_DEVNET_GUARDIAN_QUEUE.toBuffer().toString("hex"),
  authority: userAddress,
  name: "Testnet Guardian Queue",
  fee: 0,
  feeRecipient: userAddress,
  minAttestations: 3,
  oracleValidityLengthMs: 1000 * 60 * 60 * 24 * 365 * 5,
  isGuardianQueue: true,
  switchboardAddress: ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID,
});

// send the transaction
const guardianQueueTxResponse = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: guardianQueueInitTx,
  options: {
    showEffects: true,
  },
});

await client.waitForTransaction(guardianQueueTxResponse);

let guardianQueueId = "";
guardianQueueTxResponse.effects?.created?.forEach((c) => {
  if (c.reference.objectId) {
    guardianQueueId = c.reference.objectId;
  }
});
console.log("Guardian Queue ID:", guardianQueueId);

if (!guardianQueueId) {
  throw new Error("Failed to create guardian queue");
}

// =================================================================================================
// Oracle Queue
// =================================================================================================

const queueInitTx = new Transaction();

await Queue.initTx(sb, queueInitTx, {
  queueKey: ON_DEMAND_DEVNET_QUEUE.toBuffer().toString("hex"),
  authority: userAddress,
  name: "Testnet Oracle Queue",
  fee: 0,
  feeRecipient: userAddress,
  minAttestations: 3,
  oracleValidityLengthMs: 1000 * 60 * 60 * 24 * 7,
  guardianQueueId,
  switchboardAddress: ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID,
});

// send the transaction
const queueTxResponse = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: queueInitTx,
  options: {
    showEffects: true,
  },
});

await client.waitForTransaction(queueTxResponse);

let queueId = "";
queueTxResponse.effects?.created?.forEach((c) => {
  if (c.reference.objectId) {
    queueId = c.reference.objectId;
  }
});
console.log("Queue ID:", queueId);

if (!queueId) {
  throw new Error("Failed to create queue");
}

// =================================================================================================
// State Object Initialization
// =================================================================================================
const tx = new Transaction();
tx.moveCall({
  target: `${ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID}::set_package_id_action::run`,
  arguments: [
    tx.object(adminCap),
    tx.object(ON_DEMAND_TESTNET_STATE_OBJECT_ID),
    tx.pure.id(ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID),
  ],
});

tx.moveCall({
  target: `${ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID}::set_guardian_queue_id_action::run`,
  arguments: [
    tx.object(adminCap),
    tx.object(ON_DEMAND_TESTNET_STATE_OBJECT_ID),
    tx.pure.id(guardianQueueId),
  ],
});

tx.moveCall({
  target: `${ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID}::set_oracle_queue_id_action::run`,
  arguments: [
    tx.object(adminCap),
    tx.object(ON_DEMAND_TESTNET_STATE_OBJECT_ID),
    tx.pure.id(queueId),
  ],
});

const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: {
    showEffects: true,
    showObjectChanges: true,
  },
});

console.log(res);
console.log("Successfully initialized state object");

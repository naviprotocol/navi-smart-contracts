// sui client upgrade --upgrade-capability 0x75c9afab64928bbb62039f0b4f4bb4437e5312557583c4f3d350affd705cb1ba
import { SuiClient } from "@mysten/sui/client";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 as fromB64, SUI_TYPE_ARG, toHex } from "@mysten/sui/utils";
import {
  ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID,
  ON_DEMAND_TESTNET_STATE_OBJECT_ID,
  Queue,
  State,
  SwitchboardClient,
} from "@switchboard-xyz/sui-sdk";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

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

// create new user
const userAddress = keypair.getPublicKey().toSuiAddress();

console.log(`User account ${userAddress} loaded.`);

console.log("Initializing TESTNET Setup");
const chainID = await client.getChainIdentifier();

console.log(`Chain ID: ${chainID}`);

const stateAddress = ON_DEMAND_TESTNET_STATE_OBJECT_ID;
const state = new State(sb, stateAddress);
const stateData = await state.loadData();

console.log("State Data: ", stateData);

const queue = new Queue(sb, stateData.oracleQueue);
console.log("Queue Data: ", await queue.loadData());

const switchboardAddress = ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID;

const adminCapAddress =
  "0xc256f2b0a61af132f705a5a9d345edcc802fecba3213d6002265dfeb576ece90";

const new_on_demand_package_id =
  "0x578b91ec9dcc505439b2f0ec761c23ad2c533a1c23b0467f6c4ae3d9686709f6";

const tx = new Transaction();
tx.moveCall({
  target: `${switchboardAddress}::set_package_id_action::run`,
  arguments: [
    tx.object(adminCapAddress),
    tx.object(stateAddress),
    tx.pure.id(new_on_demand_package_id),
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

console.log("On Demand Set Package ID Response: ", res);

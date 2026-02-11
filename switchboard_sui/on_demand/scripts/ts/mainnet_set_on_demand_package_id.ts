import { SuiClient } from "@mysten/sui/client";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 as fromB64, SUI_TYPE_ARG, toHex } from "@mysten/sui/utils";
import {
  ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID,
  ON_DEMAND_MAINNET_STATE_OBJECT_ID,
  Queue,
  State,
  SwitchboardClient,
} from "@switchboard-xyz/sui-sdk";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

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

console.log("Initializing MAINNET Setup");
const chainID = await client.getChainIdentifier();

console.log(`Chain ID: ${chainID}`);

const stateAddress = ON_DEMAND_MAINNET_STATE_OBJECT_ID;
const state = new State(sb, stateAddress);
const stateData = await state.loadData();

console.log("State Data: ", stateData);

const queue = new Queue(sb, stateData.oracleQueue);
console.log("Queue Data: ", await queue.loadData());

// UPDATE THIS WHEN MAKING THE CHANGE
const switchboardAddress = ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID;

const adminCapAddress =
  "0xf02428df77e94f22df093b364d7e2b47cacb96a1856f49f5e1c4927705d50050";

const newSwitchboardAddress =
  "0xe6717fb7c9d44706bf8ce8a651e25c0a7902d32cb0ff40c0976251ce8ac25655";

const tx = new Transaction();
tx.moveCall({
  target: `${switchboardAddress}::set_package_id_action::run`,
  arguments: [
    tx.object(adminCapAddress),
    tx.object(stateAddress),
    tx.pure.id(newSwitchboardAddress),
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

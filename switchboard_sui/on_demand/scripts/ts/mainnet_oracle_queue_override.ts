// sui client upgrade --upgrade-capability 0x75c9afab64928bbb62039f0b4f4bb4437e5312557583c4f3d350affd705cb1ba
import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 as fromB64, toHex, fromHex } from "@mysten/sui/utils";
import {
  Oracle,
  Queue,
  State,
  ON_DEMAND_MAINNET_STATE_OBJECT_ID,
  SwitchboardClient,
  ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID,
} from "@switchboard-xyz/sui-sdk";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import {
  getDefaultQueue,
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

console.log("Initializing MAINNET Oracle Queue Setup");
const chainID = await client.getChainIdentifier();

console.log(`Chain ID: ${chainID}`);

const state = new State(sb, ON_DEMAND_MAINNET_STATE_OBJECT_ID);
const stateData = await state.loadData();

console.log("State Data: ", stateData);

const queue = new Queue(sb, stateData.oracleQueue);
console.log("Queue Data: ", await queue.loadData());

const switchboardObjectAddress = ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID;
const gql = new SuiGraphQLClient({
  url: "https://sui-mainnet.mystenlabs.com/graphql",
});

const allOracles = await queue.loadOracleData();
console.log("All Oracles: ", allOracles);

//================================================================================================
// Initialize Oracles
//================================================================================================

// Load all the oracles on the solana queue
const solanaQueue = await getDefaultQueue();
const solanaOracleKeys = await solanaQueue.fetchOracleKeys();
const solanaOracles = await SolanaOracle.loadMany(
  solanaQueue.program,
  solanaOracleKeys
).then((oracles) => {
  oracles.forEach((o, i) => {
    o.pubkey = solanaOracleKeys[i];
  });
  return oracles;
});

// Initialize the oracles
console.log(
  "Initializing/Updating Solana Oracles, oracles:",
  solanaOracles.length
);

const oracleTx = new Transaction();

let oracleInits = 0;
let oracleUpdates = 0;

for (const oracle of solanaOracles) {
  if (allOracles.find((o) => o.oracleKey === oracle.pubkey.toBase58())) {
    const o = allOracles.find((o) => o.oracleKey === oracle.pubkey.toBase58());
    // console.log(o);
    if (o && o.secp256k1Key === toHex(oracle.enclave.secp256K1Signer)) {
      console.log("Oracle already initialized");
      continue;
    } else if (o) {
      console.log("Oracle found, updating", oracle.pubkey.toBase58());
      oracleUpdates++;
      queue.overrideOracleTx(oracleTx, {
        switchboardAddress: switchboardObjectAddress,
        oracleQueueId: stateData.oracleQueue,
        oracle: o.id, // sui oracle id
        secp256k1Key: toHex(oracle.enclave.secp256K1Signer),
        mrEnclave: toHex(oracle.enclave.mrEnclave),
        expirationTimeMs: Date.now() + 1000 * 60 * 60 * 24 * 365 * 5,
      });
    }
  } else {
    console.log("Oracle not found, initializing", oracle.pubkey.toBase58());
    oracleInits++;
    console.log(toHex(oracle.pubkey.toBuffer()));
    Oracle.initTx(sb, oracleTx, {
      oracleKey: toHex(oracle.pubkey.toBuffer()),
    });
  }
}

const senderClient = new SuiClient({
  url: MAINNET_SUI_RPC,
});

if (oracleInits > 0 || oracleUpdates > 0) {
  const res = await senderClient.signAndExecuteTransaction({
    signer: keypair,
    transaction: oracleTx,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  console.log(res);
}

// load all oracles
const allOraclesAfter = await Oracle.loadAllOracles(
  gql,
  switchboardObjectAddress
);
console.log("All Oracles After: ", allOraclesAfter);

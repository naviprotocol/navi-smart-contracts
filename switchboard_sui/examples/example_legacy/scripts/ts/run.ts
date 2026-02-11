// sui client upgrade --upgrade-capability 0x75c9afab64928bbb62039f0b4f4bb4437e5312557583c4f3d350affd705cb1ba
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 as fromB64 } from "@mysten/sui/utils";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const MAINNET_SUI_RPC = "https://fullnode.mainnet.sui.io:443";
const client = new SuiClient({
  url: MAINNET_SUI_RPC,
});
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

const exampleAddress =
  "0x3b848d34b60087ecbbb70631126b08b9a13a212537eac0386826cbe4fc70fa46";

const aggregatorAddress =
  "0xa3b4d2398c2d781bba70f189e3d0770cbcb981d9c719e84318f455057d9207dd";

const tx = new Transaction();

tx.moveCall({
  target: `${exampleAddress}::legacy::example_legacy`,
  arguments: [tx.object(aggregatorAddress)],
});

const res = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: {
    showEffects: true,
    showObjectChanges: true,
  },
});

console.log("On Demand Legacy Move Example run response: ", res);

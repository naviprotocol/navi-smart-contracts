import { Oracle } from "./oracle/index.js";
import type { QueueData } from "./queue/index.js";
import { Queue } from "./queue/index.js";
import { State } from "./state/index.js";

import { TTLCache } from "@brokerloop/ttlcache";
import type {
  MoveStruct,
  MoveValue,
  SuiObjectResponse,
} from "@mysten/sui/client";
import type { SuiClient } from "@mysten/sui/client";
import type { Queue as SolanaQueue } from "@switchboard-xyz/on-demand";
import BN from "bn.js";

export { Oracle, Queue, State };

export * from "./aggregator/index.js";
export * from "./oracle/index.js";
export * from "./queue/index.js";
export * from "./state/index.js";
export * from "@switchboard-xyz/on-demand";

export const ON_DEMAND_MAINNET_OBJECT_PACKAGE_ID =
  "0xc3c7e6eb7202e9fb0389a2f7542b91cc40e4f7a33c02554fec11c4c92f938ea3";
export const ON_DEMAND_MAINNET_STATE_OBJECT_ID =
  "0x93d2a8222bb2006d16285ac858ec2ae5f644851917504b94debde8032664a791";
export const ON_DEMAND_TESTNET_OBJECT_PACKAGE_ID =
  "0xdd96e1c8d6d61c4642b9b73eefb1021cc5f93f489b794bca11c81d55fcf43ce2";
export const ON_DEMAND_TESTNET_STATE_OBJECT_ID =
  "0x2086fdde07a8f4726a3fc72d6ef1021343a781d42de6541ca412cf50b4339ad6";

// ==============================================================================
// Caching for Fetch Update Ix

// 1 min cache for sui cache
export const suiQueueCache = new TTLCache<string, QueueData>({
  ttl: 1000 * 60,
});

// 5 min solana queue cache - reloads the sol program every 5 minutes max
export const solanaProgramCache = new TTLCache<string, SolanaQueue>({
  ttl: 1000 * 60 * 5,
});

// ==============================================================================

export interface SwitchboardState {
  switchboardAddress: string;
  guardianQueueId: string;
  oracleQueueId: string;
  mainnet: boolean;
}

export interface CommonOptions {
  switchboardAddress?: string;
  guardianQueueId?: string;
  oracleQueueId?: string;
  chainId?: string;
}

export class SwitchboardClient {
  state: Promise<SwitchboardState | undefined>;

  constructor(readonly client: SuiClient) {
    this.state = getSwitchboardState(client);
  }

  /**
   * Fetch the current state of the Switchboard (on-demand package ID, guardian queue ID, oracle queue ID)
   * @param retries Number of retries to fetch the state
   */
  async fetchState(
    options?: CommonOptions,
    retries: number = 3
  ): Promise<SwitchboardState> {
    if (retries <= 0) {
      throw new Error(
        "Failed to fetch Switchboard state after multiple attempts"
      );
    }

    try {
      const state = await this.state;
      if (!state) {
        this.state = getSwitchboardState(this.client, options);
        return this.fetchState(options, retries - 1);
      }

      return {
        switchboardAddress:
          options?.switchboardAddress ?? state.switchboardAddress,
        guardianQueueId: options?.guardianQueueId ?? state.guardianQueueId,
        oracleQueueId: options?.oracleQueueId ?? state.oracleQueueId,
        mainnet: state.mainnet,
      };
    } catch (error) {
      console.error("Error fetching Switchboard state, retrying...");
      return this.fetchState(options, retries - 1);
    }
  }
}

// Helper function to get the Switchboard state
export async function getSwitchboardState(
  client: SuiClient,
  options?: CommonOptions
): Promise<SwitchboardState | undefined> {
  try {
    const chainId = options?.chainId ?? (await client.getChainIdentifier());
    const mainnet = chainId !== "4c78adac"; // Check if mainnet or testnet
    const data = await State.fetch(
      client,
      mainnet
        ? ON_DEMAND_MAINNET_STATE_OBJECT_ID
        : ON_DEMAND_TESTNET_STATE_OBJECT_ID
    );

    return {
      switchboardAddress: options?.switchboardAddress ?? data.onDemandPackageId,
      guardianQueueId: options?.guardianQueueId ?? data.guardianQueue,
      oracleQueueId: options?.oracleQueueId ?? data.oracleQueue,
      mainnet,
    };
  } catch (error) {
    console.error("Failed to retrieve Switchboard state:", error);
  }
}

export function getFieldsFromObject(response: SuiObjectResponse): {
  [key: string]: MoveValue;
} {
  // Check if 'data' and 'content' exist and are of the expected type
  if (
    response.data?.content &&
    response.data.content.dataType === "moveObject" &&
    !Array.isArray(response.data.content.fields) &&
    !("type" in response.data.content.fields)
  ) {
    // Safely return 'fields' from 'content'
    return response.data.content.fields;
  }

  throw new Error("Invalid response data");
}

export class ObjectParsingHelper {
  public static asString(value: MoveValue): string {
    if (typeof value === "string") {
      return value;
    }
    throw new Error("Invalid Move String");
  }

  public static asNumber(value: MoveValue): number {
    try {
      return parseInt(value as string);
    } catch (e) {
      throw new Error("Invalid Move Number");
    }
  }

  public static asArray(value: MoveValue): MoveValue[] {
    if (Array.isArray(value)) {
      return value;
    }
    throw new Error("Invalid MoveValueArray");
  }

  public static asUint8Array(value: MoveValue): Uint8Array {
    if (Array.isArray(value) && value.every((v) => typeof v === "number")) {
      return new Uint8Array(value as number[]);
    }
    throw new Error("Invalid Move Uint8Array");
  }

  public static asId(value: MoveValue): string {
    if (typeof value === "object" && "id" in value) {
      const idWrapper = value as { id: string };
      return idWrapper.id;
    }
    throw new Error("Invalid Move Id");
  }

  public static asStruct(value: MoveValue): MoveStruct {
    if (typeof value === "object" && !Array.isArray(value)) {
      return value as MoveStruct;
    }
    throw new Error("Invalid Move Struct");
  }

  // Parse switchboard move decimal into BN, whether or not nested in "fields"
  public static asBN(value: MoveValue): BN {
    if (typeof value !== "object") {
      throw new Error("Invalid Move BN Input Type");
    }

    const target = "fields" in value ? value.fields : value;

    if (typeof target === "object" && "value" in target && "neg" in target) {
      return new BN(target.value.toString()).mul(
        target.neg ? new BN(-1) : new BN(1)
      );
    }

    throw new Error("Invalid Move BN");
  }
}

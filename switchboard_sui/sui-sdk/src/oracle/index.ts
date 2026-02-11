import type { CommonOptions, SwitchboardClient } from "../index.js";
import {
  getFieldsFromObject,
  ObjectParsingHelper,
  Queue,
  solanaProgramCache,
  suiQueueCache,
} from "../index.js";

import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schemas/2024.4";
import type { Transaction } from "@mysten/sui/transactions";
import {
  fromBase58,
  fromBase64,
  fromHex,
  SUI_CLOCK_OBJECT_ID,
  toBase58,
  toHex,
} from "@mysten/sui/utils";
import type {
  BridgeEnclaveResponse,
  Queue as SolanaQueue,
} from "@switchboard-xyz/on-demand";
import {
  getDefaultDevnetGuardianQueue,
  getDefaultGuardianQueue,
  ON_DEMAND_DEVNET_GUARDIAN_QUEUE,
  ON_DEMAND_MAINNET_GUARDIAN_QUEUE,
} from "@switchboard-xyz/on-demand";

export interface OracleInitParams extends CommonOptions {
  oracleKey: string;
  isGuardian?: boolean;
}

export interface OracleAttestParams extends CommonOptions {
  minAttestations: number;
  isGuardian?: boolean;
  solanaRPCUrl?: string;
}
export interface OracleData {
  expirationTime: number;
  id: string;
  mrEnclave: string;
  oracleKey: string;
  queue: string;
  queueKey: string;
  secp256k1Key: string;
  validAttestations: any[];
}

export class Oracle {
  constructor(readonly client: SwitchboardClient, readonly address: string) {}

  /**
   * Create a new Oracle
   */
  public static async initTx(
    client: SwitchboardClient,
    tx: Transaction,
    options: OracleInitParams
  ) {
    const { switchboardAddress, oracleQueueId, guardianQueueId } =
      await client.fetchState(options);
    const queueId = options.isGuardian ? guardianQueueId : oracleQueueId;
    tx.moveCall({
      target: `${switchboardAddress}::oracle_init_action::run`,
      arguments: [
        tx.pure.vector("u8", Array.from(fromHex(options.oracleKey))),
        tx.object(queueId),
      ],
    });
  }

  /**
   * Oracle attest Tx
   */
  public async attestTx(tx: Transaction, options: OracleAttestParams) {
    const { switchboardAddress, oracleQueueId, guardianQueueId } =
      await this.client.fetchState(options);

    const queueId = options.isGuardian ? guardianQueueId : oracleQueueId;

    const oracleData = await this.loadData();

    // get the sui queue from cache
    let suiQueue = suiQueueCache.get(oracleData.queue);
    if (!suiQueue) {
      const queue = await new Queue(this.client, queueId).loadData();
      suiQueueCache.set(queueId, queue);
      suiQueue = queue;
    }

    let suiGuardianQueue = suiQueueCache.get(suiQueue.guardianQueueId);
    if (!suiGuardianQueue) {
      const queue = await new Queue(
        this.client,
        suiQueue.guardianQueueId
      ).loadData();
      suiQueueCache.set(suiQueue.guardianQueueId, queue);
      suiGuardianQueue = queue;
    }

    // load the solana guardian queue from cache or fetch it
    let solanaGuardianQueue: SolanaQueue;
    if (
      suiGuardianQueue.queueKey == ON_DEMAND_MAINNET_GUARDIAN_QUEUE.toBase58()
    ) {
      solanaGuardianQueue = solanaProgramCache.get(
        ON_DEMAND_MAINNET_GUARDIAN_QUEUE.toBase58()
      );
      if (!solanaGuardianQueue) {
        solanaGuardianQueue = await getDefaultGuardianQueue(
          options.solanaRPCUrl
        );
        solanaProgramCache.set(
          ON_DEMAND_MAINNET_GUARDIAN_QUEUE.toBase58(),
          solanaGuardianQueue
        );
      }
    } else if (
      suiQueue.queueKey == ON_DEMAND_DEVNET_GUARDIAN_QUEUE.toBase58()
    ) {
      solanaGuardianQueue = solanaProgramCache.get(
        ON_DEMAND_DEVNET_GUARDIAN_QUEUE.toBase58()
      );
      if (!solanaGuardianQueue) {
        solanaGuardianQueue = await getDefaultDevnetGuardianQueue(
          options.solanaRPCUrl
        );
        solanaProgramCache.set(
          ON_DEMAND_DEVNET_GUARDIAN_QUEUE.toBase58(),
          solanaGuardianQueue
        );
      }
    }

    // load up the gateways
    const guardianGateways = await solanaGuardianQueue.fetchAllGateways();

    // get the bridge messages
    const getBridgingMessages = async (): Promise<BridgeEnclaveResponse[]> => {
      // shuffle the gateways
      guardianGateways.sort(() => Math.random() - 0.5);

      // slice min attestations
      const gateways = guardianGateways.slice(0, options.minAttestations);

      // bridge gateway promises
      const gatewayPromises = gateways.map((g) =>
        g.fetchBridgingMessage({
          chainHash: "0".repeat(64),
          oraclePubkey: toHex(fromBase58(oracleData.oracleKey)),
          queuePubkey: toHex(fromBase58(oracleData.queueKey)),
        })
      );

      // wait until they're all settled
      const messages = await Promise.allSettled(gatewayPromises);

      // get the bridge messages
      return messages
        .map((m) => {
          if (m.status === "fulfilled") {
            return m.value;
          }
        })
        .filter((m) => m);
    };

    const bridgeMessages: BridgeEnclaveResponse[] = [];

    // try 3 times to get the bridge messages
    for (let i = 0; i < 3; i++) {
      bridgeMessages.push(...(await getBridgingMessages()));
      if (bridgeMessages.length >= options.minAttestations) {
        break;
      }
    }

    // if we don't have enough bridge messages - throw an error
    if (bridgeMessages.length < options.minAttestations) {
      throw new Error("Not enough bridge messages");
    }

    bridgeMessages.forEach((message: BridgeEnclaveResponse) => {
      const signature = Array.from(fromBase64(message.signature));
      signature.push(message.recovery_id);
      const mrEnclave = message.mr_enclave;
      const secp256k1Key = message.oracle_secp256k1_enclave_signer;
      const guardian = toBase58(fromHex(message.guardian));
      const guardianId = suiGuardianQueue.existingOracles.find(
        (o) => o.oracleKey === guardian
      )?.oracleId;

      if (!guardianId) {
        console.error("Guardian not found", guardian);
        return;
      }

      tx.moveCall({
        target: `${switchboardAddress}::oracle_attest_action::run`,
        arguments: [
          tx.object(this.address),
          tx.object(oracleData.queue),
          tx.object(guardianId),
          tx.pure.u64(message.timestamp),
          tx.pure.vector("u8", Array.from(fromHex(mrEnclave))),
          tx.pure.vector("u8", Array.from(fromHex(secp256k1Key))),
          tx.pure.vector("u8", signature),
          tx.object(SUI_CLOCK_OBJECT_ID),
        ],
      });
    });
  }

  public static parseOracleData(oracleData: any): OracleData {
    return {
      expirationTime: ObjectParsingHelper.asNumber(
        oracleData.expiration_time_ms
      ),
      id: ObjectParsingHelper.asId(oracleData.id),
      mrEnclave: toHex(ObjectParsingHelper.asUint8Array(oracleData.mr_enclave)),
      oracleKey: toBase58(
        ObjectParsingHelper.asUint8Array(oracleData.oracle_key)
      ),
      queue: ObjectParsingHelper.asString(oracleData.queue),
      queueKey: toBase58(
        ObjectParsingHelper.asUint8Array(oracleData.queue_key)
      ),
      secp256k1Key: toHex(
        ObjectParsingHelper.asUint8Array(oracleData.secp256k1_key)
      ),
      validAttestations: ObjectParsingHelper.asArray(
        oracleData.valid_attestations
      ),
    };
  }

  /**
   * Get the oracle data object
   */
  public async loadData(): Promise<OracleData> {
    const oracleData = await this.client.client
      .getObject({
        id: this.address,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then(getFieldsFromObject);

    return Oracle.parseOracleData(oracleData);
  }

  public static async loadAllOracles(
    graphqlClient: SuiGraphQLClient,
    switchboardAddress: string
  ): Promise<OracleData[]> {
    const fetchAggregatorsQuery = graphql(`
      query {
        objects(
          filter: {
            type: "${switchboardAddress}::oracle::Oracle"
          }
        ) {
          nodes {
            address
            digest
            asMoveObject {
              contents {
                json
              }
            }
          }
        }
      }
    `);
    const result = await graphqlClient.query({
      query: fetchAggregatorsQuery,
    });

    const oracleData: OracleData[] = result.data?.objects?.nodes?.map(
      (result) => {
        const moveObject = result.asMoveObject.contents.json as any;

        // build the data object from moveObject which looks like the above json
        return {
          expirationTime: ObjectParsingHelper.asNumber(
            moveObject.expiration_time_ms
          ),
          id: moveObject.id,
          mrEnclave: toHex(
            ObjectParsingHelper.asUint8Array(moveObject.mr_enclave)
          ),
          oracleKey: toBase58(
            ObjectParsingHelper.asUint8Array(moveObject.oracle_key)
          ),
          queue: ObjectParsingHelper.asString(moveObject.queue),
          queueKey: toBase58(
            ObjectParsingHelper.asUint8Array(moveObject.queue_key)
          ),
          secp256k1Key: toHex(
            ObjectParsingHelper.asUint8Array(moveObject.secp256k1_key)
          ),
          validAttestations: ObjectParsingHelper.asArray(
            moveObject.valid_attestations
          ),
        };
      }
    );

    return oracleData;
  }

  public static async loadMany(
    client: SwitchboardClient,
    oracles: string[]
  ): Promise<OracleData[]> {
    const oracleData = await client.client
      .multiGetObjects({
        ids: oracles,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then((o) => o.map(getFieldsFromObject));

    return oracleData.map((o) => this.parseOracleData(o));
  }
}

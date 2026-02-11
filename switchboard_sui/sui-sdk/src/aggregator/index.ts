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
  fromBase64,
  fromHex,
  SUI_CLOCK_OBJECT_ID,
  SUI_TYPE_ARG,
  toBase58,
  toHex,
} from "@mysten/sui/utils";
import { CrossbarClient, OracleJob } from "@switchboard-xyz/common";
import type {
  FeedEvalResponse,
  Queue as SolanaQueue,
} from "@switchboard-xyz/on-demand";
import {
  getDefaultDevnetQueue,
  getDefaultQueue,
  ON_DEMAND_DEVNET_QUEUE,
  ON_DEMAND_MAINNET_QUEUE,
} from "@switchboard-xyz/on-demand";
import type BN from "bn.js";

export interface AggregatorInitParams extends CommonOptions {
  authority: string;
  name: string;
  feedHash: string;
  minSampleSize: number;
  maxStalenessSeconds: number;
  maxVariance: number;
  minResponses: number;
}

export interface AggregatorConfigParams extends CommonOptions {
  aggregator: string;
  name: string;
  feedHash: string;
  minSampleSize: number;
  maxStalenessSeconds: number;
  maxVariance: number;
  minResponses: number;
}

export interface AggregatorSetAuthorityParams extends CommonOptions {
  aggregator: string;
  newAuthority: string;
}

export interface AggregatorConfigs {
  feedHash: string;
  maxVariance: number;
  minResponses: number;
  minSampleSize: number;
}

export interface AggregatorFetchUpdateIxParams extends CommonOptions {
  solanaRPCUrl?: string;
  crossbarUrl?: string;
  crossbarClient?: CrossbarClient;

  // If passed in, Sui Aggregator load can be skipped
  feedConfigs?: AggregatorConfigs;

  // If passed in, Sui Queue load can be skipped
  queue?: Queue;
}

export interface CurrentResultData {
  maxResult: BN;
  maxTimestamp: number;
  mean: BN;
  minResult: BN;
  minTimestamp: number;
  range: BN;
  result: BN;
  stdev: BN;
}

export interface Update {
  oracle: string;
  value: BN;
  timestamp: number;
}

export interface AggregatorData {
  id: string;
  authority: string;
  createdAtMs: number;
  currentResult: CurrentResultData;
  feedHash: string;
  maxStalenessSeconds: number;
  maxVariance: number;
  minResponses: number;
  minSampleSize: number;
  name: string;
  queue: string;
  updateState: {
    currIdx: number;
    results: Update[];
  };
}

export class Aggregator {
  public crossbarClient?: CrossbarClient;
  public feedHash?: string;

  constructor(readonly client: SwitchboardClient, readonly address: string) {}

  /**
   * Create a new Aggregator
   * @param client - SuiClient
   * @param tx - Transaction
   * @param options - AggregatorInitParams
   * @constructor
   */
  public static async initTx(
    client: SwitchboardClient,
    tx: Transaction,
    options: AggregatorInitParams
  ) {
    const { switchboardAddress, oracleQueueId } = await client.fetchState(
      options
    );

    tx.moveCall({
      target: `${switchboardAddress}::aggregator_init_action::run`,
      arguments: [
        tx.object(oracleQueueId),
        tx.pure.address(options.authority),
        tx.pure.string(options.name),
        tx.pure.vector("u8", Array.from(fromHex(options.feedHash))),
        tx.pure.u64(options.minSampleSize),
        tx.pure.u64(options.maxStalenessSeconds),
        tx.pure.u64(options.maxVariance),
        tx.pure.u32(options.minResponses),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });
  }

  /**
   * Set configs for the Aggregator
   * @param tx - Transaction
   * @param options - AggregatorConfigParams
   */
  public async setConfigsTx(tx: Transaction, options: AggregatorConfigParams) {
    const { switchboardAddress } = await this.client.fetchState(options);

    tx.moveCall({
      target: `${switchboardAddress}::aggregator_set_configs_action::run`,
      arguments: [
        tx.object(this.address),
        tx.pure.vector("u8", Array.from(fromHex(options.feedHash))),
        tx.pure.u64(options.minSampleSize),
        tx.pure.u64(options.maxStalenessSeconds),
        tx.pure.u64(options.maxVariance),
        tx.pure.u32(options.minResponses),
      ],
    });
  }

  /**
   * Set the feed authority
   * @param tx - Transaction
   * @param options - AggregatorSetAuthorityParams
   */
  public async setAuthorityTx(
    tx: Transaction,
    options: AggregatorSetAuthorityParams
  ) {
    const { switchboardAddress } = await this.client.fetchState(options);

    tx.moveCall({
      target: `${switchboardAddress}::aggregator_set_authority_action::run`,
      arguments: [
        tx.object(this.address),
        tx.pure.address(options.newAuthority),
      ],
    });
  }

  /**
   * Pull feed tx
   * @param tx - Transaction
   * @param options - CommonOptions
   */
  public async fetchUpdateTx(
    tx: Transaction,
    options?: AggregatorFetchUpdateIxParams
  ): Promise<{
    responses: FeedEvalResponse[];
    failures: string[];
  }> {
    const { switchboardAddress, oracleQueueId } = await this.client.fetchState(
      options
    );

    // get the feed configs if we need them / they aren't passed in
    let feedConfigs = options?.feedConfigs;
    if (!feedConfigs) {
      const aggregatorData = await this.loadData();
      feedConfigs = {
        minSampleSize: aggregatorData.minSampleSize,
        feedHash: aggregatorData.feedHash,
        maxVariance: aggregatorData.maxVariance,
        minResponses: aggregatorData.minResponses,
      };
    }

    // get the sui queue from cache
    let suiQueue = suiQueueCache.get(oracleQueueId);
    if (!suiQueue) {
      const queue = await new Queue(this.client, oracleQueueId).loadData();
      suiQueueCache.set(oracleQueueId, queue);
      suiQueue = queue;
    }

    // load the solana queue from cache or fetch it
    let solanaQueue: SolanaQueue;
    if (suiQueue.queueKey === ON_DEMAND_MAINNET_QUEUE.toBase58()) {
      solanaQueue = solanaProgramCache.get(ON_DEMAND_MAINNET_QUEUE.toBase58());
      if (!solanaQueue) {
        solanaQueue = await getDefaultQueue(options?.solanaRPCUrl);
        solanaProgramCache.set(ON_DEMAND_MAINNET_QUEUE.toBase58(), solanaQueue);
      }
    } else if (suiQueue.queueKey === ON_DEMAND_DEVNET_QUEUE.toBase58()) {
      solanaQueue = solanaProgramCache.get(ON_DEMAND_DEVNET_QUEUE.toBase58());
      if (!solanaQueue) {
        solanaQueue = await getDefaultDevnetQueue(options?.solanaRPCUrl);
        solanaProgramCache.set(ON_DEMAND_DEVNET_QUEUE.toBase58(), solanaQueue);
      }
    } else {
      throw new Error("[fetchUpdateTx]: QUEUE NOT FOUND");
    }

    // fail out if we can't load the queue
    if (!solanaQueue) {
      throw new Error(
        `Could not load the Switchboard Queue - Queue pubkey: ${suiQueue.queueKey}`
      );
    }

    // fetch the jobs from crossbar
    const crossbarClient =
      options?.crossbarClient ??
      new CrossbarClient(
        options?.crossbarUrl ?? "https://crossbar.switchboard.xyz"
      );
    const jobs: OracleJob[] = await crossbarClient
      .fetch(feedConfigs.feedHash)
      .then((res) => res.jobs.map((job) => OracleJob.fromObject(job)));

    // fetch the signatures
    const { responses, failures } = await solanaQueue.fetchSignatures({
      jobs,

      // Make this more granular in the canonical fetch signatures (within @switchboard-xyz/on-demand)
      maxVariance: Math.floor(feedConfigs.maxVariance / 1e9),
      minResponses: feedConfigs.minResponses,
      numSignatures: feedConfigs.minSampleSize,

      // blockhash checks aren't possible yet on SUI
      recentHash: toBase58(new Uint8Array(32)),
      useTimestamp: true,
    });

    // filter out responses that don't have available oracles
    const validOracles = new Set(
      suiQueue.existingOracles.map((o) => o.oracleKey)
    );

    const validResponses = responses.filter((r) => {
      return validOracles.has(toBase58(fromHex(r.oracle_pubkey)));
    });

    // if we have no valid responses (or not enough), fail out
    if (
      !validResponses.length ||
      validResponses.length < feedConfigs.minSampleSize
    ) {
      // maybe retry by recursing into the same function / add a retry count
      throw new Error("Not enough valid oracle responses.");
    }

    // split the gas coin into the right amount for each response
    const coins = tx.splitCoins(
      tx.gas,
      validResponses.map(() => suiQueue.fee)
    );

    // map the responses into the tx
    validResponses.forEach((response, i) => {
      const oracle = suiQueue.existingOracles.find(
        (o) => o.oracleKey === toBase58(fromHex(response.oracle_pubkey))
      )!;

      const signature = Array.from(fromBase64(response.signature));
      signature.push(response.recovery_id);

      tx.moveCall({
        target: `${switchboardAddress}::aggregator_submit_result_action::run`,
        arguments: [
          tx.object(this.address),
          tx.object(suiQueue.id),
          tx.pure.u128(response.success_value),
          tx.pure.bool(response.success_value.startsWith("-")),
          tx.pure.u64(response.timestamp!),
          tx.object(oracle.oracleId),
          tx.pure.vector("u8", signature),
          tx.object(SUI_CLOCK_OBJECT_ID),
          coins[i],
        ],
        typeArguments: [SUI_TYPE_ARG],
      });
    });

    return { responses, failures };
  }

  /**
   * Get the feed data object
   */
  public async loadData(): Promise<AggregatorData> {
    const aggregatorData = await this.client.client
      .getObject({
        id: this.address,
        options: {
          showContent: true,
          showType: false,
        },
      })
      .then(getFieldsFromObject);

    const currentResult = (aggregatorData.current_result as any).fields;
    const updateState = (aggregatorData.update_state as any).fields;

    // build the data object
    const data: AggregatorData = {
      id: ObjectParsingHelper.asId(aggregatorData.id),
      authority: ObjectParsingHelper.asString(aggregatorData.authority),
      createdAtMs: ObjectParsingHelper.asNumber(aggregatorData.created_at_ms),
      currentResult: {
        maxResult: ObjectParsingHelper.asBN(currentResult.max_result),
        maxTimestamp: ObjectParsingHelper.asNumber(
          currentResult.max_timestamp_ms
        ),
        mean: ObjectParsingHelper.asBN(currentResult.mean),
        minResult: ObjectParsingHelper.asBN(currentResult.min_result),
        minTimestamp: ObjectParsingHelper.asNumber(
          currentResult.min_timestamp_ms
        ),
        range: ObjectParsingHelper.asBN(currentResult.range),
        result: ObjectParsingHelper.asBN(currentResult.result),
        stdev: ObjectParsingHelper.asBN(currentResult.stdev),
      },
      feedHash: toHex(
        ObjectParsingHelper.asUint8Array(aggregatorData.feed_hash)
      ),
      maxStalenessSeconds: ObjectParsingHelper.asNumber(
        aggregatorData.max_staleness_seconds
      ),
      maxVariance: ObjectParsingHelper.asNumber(aggregatorData.max_variance),
      minResponses: ObjectParsingHelper.asNumber(aggregatorData.min_responses),
      minSampleSize: ObjectParsingHelper.asNumber(
        aggregatorData.min_sample_size
      ),
      name: ObjectParsingHelper.asString(aggregatorData.name),
      queue: ObjectParsingHelper.asString(aggregatorData.queue),
      updateState: {
        currIdx: ObjectParsingHelper.asNumber(updateState.curr_idx),
        results: updateState.results.map((r: any) => {
          const oracleId = r.fields.oracle;
          const value = ObjectParsingHelper.asBN(r.fields.result.fields);
          const timestamp = parseInt(r.fields.timestamp_ms);
          return {
            oracle: oracleId,
            value,
            timestamp,
          };
        }),
      },
    };

    return data;
  }

  /**
   * Load all feeds
   */
  public static async loadAllFeeds(
    graphqlClient: SuiGraphQLClient,
    switchboardAddress: string
  ): Promise<AggregatorData[]> {
    // Query to fetch Aggregator objects with pagination supported.
    const query = graphql(`
      query($cursor: String) {
        objects(
          first: 50,
          after: $cursor,
          filter: {
            type: "${switchboardAddress}::aggregator::Aggregator"
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
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    `);

    const parseAggregator = (moveObject: any): AggregatorData => {
      return {
        id: moveObject.id,
        authority: moveObject.authority,
        createdAtMs: ObjectParsingHelper.asNumber(moveObject.created_at_ms),
        currentResult: {
          maxResult: ObjectParsingHelper.asBN(
            moveObject.current_result.max_result
          ),
          maxTimestamp: ObjectParsingHelper.asNumber(
            moveObject.current_result.max_timestamp_ms
          ),
          mean: ObjectParsingHelper.asBN(moveObject.current_result.mean),
          minResult: ObjectParsingHelper.asBN(
            moveObject.current_result.min_result
          ),
          minTimestamp: ObjectParsingHelper.asNumber(
            moveObject.current_result.min_timestamp_ms
          ),
          range: ObjectParsingHelper.asBN(moveObject.current_result.range),
          result: ObjectParsingHelper.asBN(moveObject.current_result.result),
          stdev: ObjectParsingHelper.asBN(moveObject.current_result.stdev),
        },
        feedHash: toHex(ObjectParsingHelper.asUint8Array(moveObject.feed_hash)),
        maxStalenessSeconds: ObjectParsingHelper.asNumber(
          moveObject.max_staleness_seconds
        ),
        maxVariance: ObjectParsingHelper.asNumber(moveObject.max_variance),
        minResponses: ObjectParsingHelper.asNumber(moveObject.min_responses),
        minSampleSize: ObjectParsingHelper.asNumber(moveObject.min_sample_size),
        name: ObjectParsingHelper.asString(moveObject.name),
        queue: ObjectParsingHelper.asString(moveObject.queue),
        updateState: {
          currIdx: ObjectParsingHelper.asNumber(
            moveObject.update_state.curr_idx
          ),
          results: moveObject.update_state.results.map((r: any) => {
            const oracleId = r.oracle;
            const value = ObjectParsingHelper.asBN(r.result);
            const timestamp = parseInt(r.timestamp_ms);
            return {
              oracle: oracleId,
              value,
              timestamp,
            };
          }),
        },
      };
    };

    const fetchAggregators = async (cursor: string | null) => {
      const results = await graphqlClient.query({
        query,
        variables: { cursor },
      });

      const aggregators: AggregatorData[] =
        results.data?.objects?.nodes?.map((result) => {
          const moveObject = result.asMoveObject!.contents!.json as any;
          // build the data object from moveObject which looks like the above json
          return parseAggregator(moveObject);
        }) ?? [];
      const hasNextPage = results.data?.objects?.pageInfo?.hasNextPage ?? false;
      const endCursor = results.data?.objects?.pageInfo?.endCursor ?? null;

      // Recursively fetch the next page if there is one.
      if (hasNextPage) aggregators.push(...(await fetchAggregators(endCursor)));
      // Return the list of aggregators.
      return aggregators;
    };
    return await fetchAggregators(null);
  }
}

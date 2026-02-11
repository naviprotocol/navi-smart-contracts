import type { SwitchboardClient } from "../index.js";
import { getFieldsFromObject, ObjectParsingHelper } from "../index.js";

import type { SuiClient } from "@mysten/sui/client";

export interface StateData {
  id: string;
  guardianQueue: string;
  oracleQueue: string;
  onDemandPackageId: string;
}

export class State {
  constructor(readonly client: SwitchboardClient, readonly address: string) {}

  /**
   * Get the state data object
   */
  public async loadData(): Promise<StateData> {
    const receivedData = await this.client.client
      .getObject({
        id: this.address,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then(getFieldsFromObject);

    // return the data in camelCase
    return State.parseStateData(receivedData);
  }

  public static parseStateData(receivedData: any): StateData {
    // build from the result
    return {
      guardianQueue: ObjectParsingHelper.asString(receivedData.guardian_queue),
      id: ObjectParsingHelper.asId(receivedData.id),
      onDemandPackageId: ObjectParsingHelper.asString(
        receivedData.on_demand_package_id
      ),
      oracleQueue: ObjectParsingHelper.asString(receivedData.oracle_queue),
    };
  }

  public static async fetch(
    client: SuiClient,
    address: string
  ): Promise<StateData> {
    const receivedData = await client
      .getObject({
        id: address,
        options: {
          showContent: true,
          showType: true,
        },
      })
      .then(getFieldsFromObject);
    return State.parseStateData(receivedData);
  }
}

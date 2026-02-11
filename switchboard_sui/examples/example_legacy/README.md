# Example with Legacy Move

This example shows how to use Switchboard On-Demand data with legacy move.

## Prerequisites

- Bun.sh install
- Sui move environment

## Installation

```bash
bun install
```

## Usage

### 0. (Optional) Deploy the Contract

- Ensure the Move.toml is configured for the correct network and the sui client environment matches that.

```bash
sui client publish
```

### 1. Configure the Script

Edit the `scripts/ts/run.ts` file to set the desired parameters. Particularly the addresses for the aggregator and the contract. Throw in your desired aggregator address for an update.

### 2. Run the Script

```bash
bun run scripts/ts/run.ts
```

### 3. Check the Output

The script will output the effects.

# Example with Move2024

This example shows how to use Switchboard On-Demand data with Move2024.

## Prerequisites

- Bun.sh install
- Sui move environment

## Installation

```bash
bun install
```

## Usage

### 0. (Optional) Deploy the Contract

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

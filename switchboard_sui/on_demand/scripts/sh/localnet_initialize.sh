#!/bin/bash

# Variables - set these according to your project
INITIAL_FUNDS=1000000000                # Adjust the amount of funds if needed

# Step 2: Retrieve the current active address
echo "Retrieving the current active address..."
WALLET_ADDRESS=$(sui client active-address | grep -o '0x[0-9a-fA-F]\+')

if [ -z "$WALLET_ADDRESS" ]; then
  echo "Error: No active address found. Please set an active address in the Sui CLI."
  cleanup
  exit 1
fi

echo "Using active wallet address: $WALLET_ADDRESS"

# Step 3: Fund the wallet
echo "Funding the wallet with $INITIAL_FUNDS SUI tokens..."
sui client faucet $WALLET_ADDRESS

# Optional: wait to ensure funding completion
sleep 5

# Step 4: Deploy contracts
echo "Deploying contracts..."
s
# Wait for the Sui process to finish or until manually interrupted
wait $SUI_PID

# Completion message
echo "Local testnet setup complete. Wallet funded and contracts deployed."

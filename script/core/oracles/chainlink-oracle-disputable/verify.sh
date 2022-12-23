#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

echo "Please enter the chain id..."
read chain_id

echo ""

echo "Please enter the deployed ChainlinkOracleDisputable address..."
read oracle

echo ""

echo "Verifying Faucet contract on Etherscan..."

forge verify-contract \
  $oracle \
  ./src/core/oracles/ChainlinkOracleDisputable.sol:ChainlinkOracleDisputable \
  ${ETHERSCAN_API_KEY}
  --compiler-version 0.8.17+commit.8df45f5f \
  --num-of-optimizations 100000 \
  --chain-id $chain_id \
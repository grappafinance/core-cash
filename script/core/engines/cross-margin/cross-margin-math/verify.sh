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

echo "Please enter the deployed CrossMarginMath address..."
read math

echo ""

echo "Verifying CrossMarginMath contract on Etherscan..."

forge verify-contract \
  $math \
  ./src/core/engines/cross-margin/CrossMarginMath.sol:CrossMarginMath \
  ${ETHERSCAN_API_KEY} \
  --chain-id $chain_id \
  --compiler-version 0.8.17+commit.8df45f5f \
  --num-of-optimizations 100000 \
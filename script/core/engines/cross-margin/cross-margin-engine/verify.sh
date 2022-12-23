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

echo "Please enter the deployed CrossMarginEngine address..."
read engine

echo ""

echo "Please enter the CrossMarginLib address..."
read lib

echo ""

echo "Please enter the CrossMarginMath address..."
read math

echo ""

echo "Verifying CrossMarginEngine contract on Etherscan..."

forge verify-contract \
  $engine \
  ./src/core/engines/cross-margin/CrossMarginEngine.sol:CrossMarginEngine \
  ${ETHERSCAN_API_KEY} \
  --chain-id $chain_id \
  --compiler-version 0.8.17+commit.8df45f5f \
  --num-of-optimizations 100000 \
  --constructor-args-path script/core/engines/cross-margin/cross-margin-engine/constructor-args.txt \
  --libraries src/core/engines/cross-margin/CrossMarginMath.sol:CrossMarginMath:$math \
  --libraries src/core/engines/cross-margin/CrossMarginLib.sol:CrossMarginLib:$lib \
  --watch
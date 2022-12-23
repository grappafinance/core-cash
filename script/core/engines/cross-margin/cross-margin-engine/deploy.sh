#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

ARGS=""

echo "Please enter the network name..."
read network

echo ""

echo "Please enter the CrossMarginLib address..."
read lib

echo ""

echo "Please enter the CrossMarginMath address..."
read math

echo ""

echo "Verify contract? [y/n]..."
read verify

echo ""

echo "Deploying CrossMarginEngine..."

if [ "$verify" = "y" ]
then
  ARGS="$ARGS --verify"
fi

forge create \
  ./src/core/engines/cross-margin/CrossMarginEngine.sol:CrossMarginEngine \
  -i \
  --constructor-args-path script/core/engines/cross-margin/cross-margin-engine/constructor-args.txt \
  --libraries src/core/engines/cross-margin/CrossMarginMath.sol:CrossMarginMath:$math \
  --libraries src/core/engines/cross-margin/CrossMarginLib.sol:CrossMarginLib:$lib \
  --rpc-url 'https://'$network'.infura.io/v3/'${INFURA_API_KEY} \
  --private-key ${PRIVATE_KEY} \
  $ARGS

echo ""

echo "CrossMarginEngine deployed successfully 🎉🎉🎉"
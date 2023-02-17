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

echo "Verify contract? [y/n]..."
read verify

echo ""

echo "Deploying CrossMarginEngineProxy..."

if [ "$verify" = "y" ]
then
  ARGS="$ARGS --verify"
fi

forge create \
  ./src/core/engines/cross-margin/CrossMarginEngineProxy.sol:CrossMarginEngineProxy \
  -i \
  --constructor-args-path script/core/engines/cross-margin/cross-margin-engine-proxy/constructor-args.txt \
  --rpc-url 'https://'$network'.infura.io/v3/'${INFURA_API_KEY} \
  --private-key ${PRIVATE_KEY} \
  $ARGS

echo ""

echo "CrossMarginEngineProxy deployed successfully 🎉🎉🎉"
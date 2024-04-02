#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

echo "Please enter the network name..."
read network

echo ""

if [ -f ./script/.$network ]
then
  export $(cat ./script/.$network | xargs)
else
    echo "Please set your .$network file"
    exit 1
fi

echo "Resume? [y/n]..."
read resume

echo ""

echo "Broadcast? [y/n]..."
read broadcast

echo ""

echo "Verify contract? [y/n]..."
read verify

echo ""

ARGS="--rpc-url https://$network.infura.io/v3/$INFURA_API_KEY"
ARGS="$ARGS --private-key $PRIVATE_KEY"

if [ "$resume" = "y" ]
then
  ARGS="$ARGS --resume"
fi

if [ "$broadcast" = "y" ]
then
  ARGS="$ARGS --broadcast"
fi

if [ "$verify" = "y" ]
then
  ARGS="$ARGS --verify"
fi

echo "Running script: $1"
echo "Arguments: $ARGS"

forge script $1 $ARGS

echo "Script ran successfully 🎉🎉🎉"
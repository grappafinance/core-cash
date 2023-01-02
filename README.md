<div align="center">
  <h1 > Grappa</h1>
  <h3 style="font-size:2.2vw;color:grey">
  An option protocol that focus on composability and capital efficiency.
  </h3>
  <img height=60 src="https://i.imgur.com/vSIO8xJ.png"> </image>
  <br/>
  <br/>
  <a href="https://github.com/foundry-rs/foundry"><img src="https://img.shields.io/static/v1?label=foundry-rs&message=foundry&color=blue&logo=github"/></a>
  <a href=https://github.com/antoncoding/grappa/actions/workflows/Slither.yml""><img src="https://github.com/antoncoding/grappa/actions/workflows/Slither.yml/badge.svg?branch=master" > </a>
  <a href=https://github.com/grappafinance/core/actions/workflows/CI.yml""><img src="https://github.com/grappafinance/core/actions/workflows/CI.yml/badge.svg?branch=master"> </a>

  <!-- reopen coverage badge again after foundry official launch coverage -->
  <a href="https://codecov.io/gh/grappafinance/core" >
<img src="https://codecov.io/gh/grappafinance/core/branch/master/graph/badge.svg?token=G52EOD1X5B"/>
</a>
  <h5 align="center"> Don't waste your capital.</h5>
  
</div>


## Introduction

This is the repository of the core component of Grappa, which is a decentralized settlement layer for options and spreads.

In our design, a option (derivative) token can be created by different **margin engine**. Users with different risk tolerance can choose among different engines based on gas cost, capital efficiency and risk of liquidation.

We also natively support call spread and put spread that can increase capital efficiency by a lot while being fully collateralized.


## Documentation

For detailed documentation about how the system architecture is designed, please visit [docs](./docs/)

## Get Started

```shell
forge build
forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment, and install husky hooks

```shell
# install yarn dependencies
yarn
# install hooks
npx husky install
```

### Test locally

```shell
forge test
```

### Run Coverage

```shell
forge coverage
```

### Linting

```shell
forge fmt
```


### Deployment

Simulate deployment for launch

```shell
forge script script/deploy-launch.sol --private-key <your PK> --fork-url <RPC-endpoint> 
```
## Run Slither

installation

```shell
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.13
solc-select use 0.8.13
```

Run analysis

```shell
slither ./src/core/FullMargin
slither ./src/core/
```


## Install Grappa into your project

With hardhat

```shell
yarn add @grappafinance/grappa-contracts

// or

npm install @grappafinance/grappa-contracts
```

With Foundry

```shell
forge install antoncoding/grappa
```

Then you will be able to import the libraries or contract interface

```solidity
pragma solidity ^0.8.0;

import "@grappafinance/grappa-contracts/src/libraries/ActionUtil.sol";

```

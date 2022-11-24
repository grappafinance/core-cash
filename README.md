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
  <a href=https://github.com/antoncoding/grappa/actions/workflows/CI.yml""><img src="https://github.com/antoncoding/grappa/actions/workflows/CI.yml/badge.svg?branch=master"> </a>

  <!-- reopen coverage badge again after foundry official launch coverage -->
  <!-- <a href="https://codecov.io/gh/antoncoding/grappa" >
<img src="https://codecov.io/gh/antoncoding/grappa/branch/master/graph/badge.svg?token=G52EOD1X5B"/>
</a> -->
  <h5 align="center"> Don't waste your capital.</h5>
  
<p align='center'>
    <img src='https://i.imgur.com/A04IOW6.jpg' alt='grappa' width="520" />
</p> 

<div style="max-width:550px">
<p align="center" style="font-size:2vw;color:grey">
  Grappa is a grape-based pomace brandy originally made to prevent waste by using leftovers. We believe there're lots of waste in capital when it comes to DeFi options, and we are here to change that.
  </p>
</div>
</div>

# Introduction

We believe that the core values of DeFi are composability and decentralization. The current DeFi option space is suffering a lot from liquidity segmentation because no one has build a trust-worthy base layer that everyone feel comfortable building on top of.

Grappa is here to be that base layer that meets different needs, and also provide an efficient exchange layer (aggregator) for people to easily exchange options across products.

The project is 100% open sourced and publicly funded on [Gitcoin](https://gitcoin.co/grants/7713/grappa-finance).

## System TLDR

Grappa is mainly composed of 2 parts:

### 1. Base Layer: Decentralized settlement layer for options and spreads

The base layer is a decentralized option (derivative) token that can be created by different **margin engine**. Users with different risk tolerance can choose among different engines based on gas cost, capital efficiency and risk of liquidation.

We also natively support call spread and put spread that can increase capital efficiency by a lot while being fully collateralized.

### 2. Exchange Layer (not in this repo)

We also planned to build an exchange layer between the same kind of option token created by different margin engine. For example: AMM to exchange between fully collateralized and partially collateralized options.

There's no development on the exchange layer yet since we're still finalizing the design of the base layer. 


## Documentation

For detailed documentation about how the system architecture is designed, please visit [docs](./docs/)


## Get Started

```shell
forge build
forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment.

```shell
yarn
```

### Test locally

```shell
forge test
```

### Run Coverage

```shell
forge coverage
```

### Deployment

Simulate deployment

```shell
forge script script/Deploy.sol --private-key <your PK> --fork-url <RPC-endpoint> 
```

## Linting

Pre-configured `solhint` and `prettier-plugin-solidity`. Can be run by

```shell
npm run lint
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

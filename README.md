<div align="center">
  <h1 align="center"> Grappa</h1>
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
  <p align="center">
    <!-- badge goes here -->
  </p>

<p align='center'>
    <img src='https://i.imgur.com/A04IOW6.jpg' alt='grappa' width="500" />
</p> 
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

### 2. Exchange Layer (research in progress)

We also planned to build an exchange layer between the same kind of option token created by different margin engine. For example: AMM to exchange between fully collateralized and partially collateralized options.

There's no development on the exchange layer yet since we're still finalizing the design of the base layer. Please go to forum to see more discussion on the design of the AMM.

### Why is it called "Grappa"?

Grappa is a grape-based pomace brandy originally made to prevent waste by using leftovers. We believe there're lots of waste in capital when it comes to DeFi options. Grappa is here to change that.

## Get Started with Grappa

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

Stimulate deployment

```shell
forge script script/Deploy.sol --private-key <your PK> --fork-url <RPC-endpoint> --ffi -vvv
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
slither ./src/core/AdvancedMargin
slither ./src/core/
```

## Base Layer Contract Architecture

![architecture](https://i.imgur.com/1HVOLYG.png)

This is the basic diagram of how contracts interact with each other in the draft version. A more detail diagram will be added later.

The 4 pieces that compose Grappa are `Oracle`, `MarginEngine` `OptionToken` and `Grappa`.

- `Grappa`: served as a registry for margin engines, assets and oracles. Also used for settling optionTokens.
- `OptionToken`: ERC1155 token that represent the right to claim for a non-negative payout at expiry. It can represent a long call position, a long put position, or debit spreads.
- `Oracle`: contracts to report spot price and expiry price of an asset. People can choose to create options that settled with different oracles.
- `MarginEngine`: each margin engine can be authorized to mint different option tokens. There should be multiple margin engines working together to provide user flexibilities to choose from, based on user preference such as gas fee, capital efficiency, composability and risk.

## List of Oracles

- `ChainlinkOracle`

## List of Margin Engines

- `FullMargin`: fully collateralized margin. can be used to mint:
  - covered call (collateralized with underlying)
  - covered put (collateralized with strike)
  - call spread (collateralized with strike or underlying)
  - put spread (collateralized with strike)
- `AdvancedMargin`: mint partially collateralized options which is 3x - 20x more capital efficient compared to fully collateralized options. Requires dependencies on vol oracle to estimate the value of option. Each 'subAccounts' can process:
  - single collateral type
  - can mint 1 call (or call spread) + 1 put (or put spread) in a single account.

### WIP Margin Engines

- **PortfolioMargin**: Support up to 30(?) positions and calculate max loss as required collateral.

Other margin system can be added to Grappa as long as it complies with the interface.


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

<div align="center">
  <h1 align="center"> Grappa 🥂</h1>
  <a href=https://github.com/antoncoding/grappa/actions/workflows/Slither.yml""><img src="https://github.com/antoncoding/grappa/actions/workflows/Slither.yml/badge.svg?branch=master" > </a>
  <a href=https://github.com/antoncoding/grappa/actions/workflows/CI.yml""><img src="https://github.com/antoncoding/grappa/actions/workflows/CI.yml/badge.svg?branch=master"> </a>

  <!-- reopen coverage badge again after foundry official launch coverage -->
  <!-- <a href="https://codecov.io/gh/antoncoding/grappa" >
<img src="https://codecov.io/gh/antoncoding/grappa/branch/master/graph/badge.svg?token=G52EOD1X5B"/>
</a> -->
  <h4 align="center"> Don't waste your capital.</h4>
  <p align="center">
    <!-- badge goes here -->
  </p>

<p align='center'>
    <img src='https://i.imgur.com/A04IOW6.jpg' alt='grappa' width="500" />
</p>  
<h6 align="center"> Built with Foundry</h6>

</div>

# Introduction

Grappa is a grape-based pomace brandy originally made to prevent waste by using leftovers.

We believe there're lots of waste in capital when it comes to DeFi options. Grappa is here to change that.

## Getting Started

```shell
forge build
forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment.

```shell
npm i
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

## Basic Contract Architecture

![architecture](https://i.imgur.com/1HVOLYG.png)

This is the basic diagram of how contracts interact with each other in the draft version. A more detail diagram will be added later.

The 4 pieces that compose Grappa are `Oracle`, `MarginEngine` `OptionToken` and `Grappa`.

- `Grappa`: served as a registry for margin engines, assets. Also used for settling optionTokens.
- `OptionToken`: ERC1155 token that represent the right to claim for a non-negative payout at expiry. It can represent a long call position, a long put position, or debit spreads.
- `Oracle`: contract to report spot price and expiry price of an asset.
- `MarginEngine`: each margin engine can be authorized to mint different option tokens. There should be multiple margin engines working together to provide user flexibilities to choose from, based on user preference such as gas fee, capital efficiency, composability and risk.

## List of Margin Engines

- `FullMargin`: fully collateralized margin. can be used to mint:
  - covered call (collateralized with underlying)
  - covered put (collateralized with strike)
  - call spread (collateralized with strike or underlying)
  - put spread (collateralized with strike)
- `AdvancedMargin`: mint partially collateralized options which is 3x - 20x more capital efficient compared to fully collateralized options. Requires dependencies on vol oracle to estimate the value of option. Each 'subAccounts' can process:
  - single collateral type
  - can mint 1 call (or call spread) + 1 put (or put spread) in a single account.

### Work-in-Progress Margin systems / Ideas

- **PortfolioMargin**: Support up to 30(?) positions and calculate max loss as required collateral.

Other margin system can be added to Grappa as long as it complies with the interface.

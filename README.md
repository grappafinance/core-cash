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

### Testing locally

You might find the compile time of `forge build` and `forge test` being long because of the `via-ir` optimization. For the purpose of developing and writing unit tests, try using the `lite` profile:

```shell
FOUNDRY_PROFILE=lite forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment.

```shell
npm i
```

## Linting

Pre-configured `solhint` and `prettier-plugin-solidity`. Can be run by

```
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

![](https://i.imgur.com/O1yqTfz.png)

This is the basic diagram of how contracts interact with each other in the draft version. A more detail diagram will be added later.

The 4 pieces that compose Grappa are `Oracle`, `MarginEngine` `OptionToken` and `Grappa`.

- `Grappa`: entry point for all the users. In charge of minting the correct product according to the connected **MarginEngine** rules
- `OptionToken`: ERC1155 token that represent the right to claim for a non-negative payout at expiry. It can represent a long call position, a long put position, or debit spreads.
- `Oracle`: contract to report spot price and expiry price of an asset. Also return an volatility index for min collateral calculation.
- `MarginEngine`: each margin engine can authorize minting different option token by keeping the collateral and do internal accounting. There should be multiple margin engines working together to provide user flexibilities to choose from, based on user preference such as gas fee, capital efficiency, composability and risk.

## List of Margin Engines

* `AdvancedMargin`: The first version of the margin system that complies with the `IMarginEngine` interface that stores account structure. The current **Simple Margin** system is capable of dealing with:
    * single collateral type
    * create native spreads
    * can mint 1 call (or call spread) +  1 put (or put spread) in a single account.

### Work-in-Progress Margin systems / Ideas

* **Simple Margin**: fully collateralized version with minimal oracle needed and risk associated.
* **PortfolioMargin**: Support up to 30 positions and calculate max loss as required collateral.

Other margin system can be added to Grappa as long as it complies with the interface.
<div align="center">
  <h1 align="center"> Grappa 🥂</h1>
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

### Developing locally

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
npm run solhint
npm run prettier
```

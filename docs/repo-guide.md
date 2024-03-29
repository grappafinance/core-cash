# Repo Guide

## Folder Structure

All contracts can be found in `src`, structured as follow:

```
src
├── config
│   ├── constants.sol
│   ├── enums.sol
│   ├── errors.sol
│   └── types.sol
├── core
│   ├── Grappa.sol
│   ├── CashOptionToken.sol
│   ├── CashOptionTokenDescriptor.sol
│   ├── engines
│   │   ├── BaseEngine.sol
│   │   └── mixins/...
│   └── oracles
│       ├── ChainlinkOracle.sol
│       └── ...
├── interfaces
├── libraries
└── test
```

### Types and Errors

All shared types, constant, enums and errors are defined in `config`.

We also separate each contract's error into each folder. All errors are prefixed with the contract name.

## Margin Engines

Shared abstract engine are located in `src/core/engines`, and each engines have their own repo. Margin engines are the most important part of the system as they decide the "rule of margining".

### BaseEngine

Currently, because there are lots of similarities between the 3 engines we implemented, we have a abstract contract called `BaseEngine` that everyone inherits from.

Engines are the entry point for option sellers (to create the option token out of the system). We're using a `execute` function for users to pass in array of operations they want to do for a given `subAccount`*. For example

note: `subAccount`*: In the current shared engine design (inherited from `BaseEngine`), we use a `subAccount` address to map ID to a specific account data structure designed by each engine. A `subAccount` is "controllable" by an address if only the last 1 bytes are different from the address. This mean each address can control 256 subAccounts. This design is inspired by [Euler](https://github.com/euler-xyz/euler-contracts/blob/cd3036e0087280365819f99ad531141894d0b7ee/contracts/BaseLogic.sol#L24), it enables cheaper auth process without defining a `owner` for each ID.

(You don't have to follow this access control design to be compatible with Grappa)

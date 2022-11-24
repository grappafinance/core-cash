# Audit Guide

This is the guide for first audit in Nov, 2022.

## Scope

During this audit, the 2 main contracts `Grappa` and `OptionToken` are in scope, and only 1 margin engine called `CrossEngine`, and 2 oracles `ChainlinkOracle` and `ChainlinkDisputableOracle` (inherits Chainlink Oracle)

![high level](./imgs/scope-audit-1.png)

## Attack surfaces

### Grappa

* Is the upgradeability being setup correctly?
* Is the settlement logic accurate
* Is the engine-based option token id control compromisable?

### OptionToken

* Can an engine create an option token with an id that it's not suppose to?

### ChainlinkOracle

* Can someone report a wrong price for an asset?
* Is it possible that someone block the oracle from accepting the settlement price? 
* Are there scenarios where the settlement price cannot be reported quickly enough after expiry (especially for stable assets)?
* Are there scenarios where no one can report a valid price?
* Any centralization risk except that owner can set aggregators?

### CrossMarginEngine

* Can someone use the engine to create under collateralized options
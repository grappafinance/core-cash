# Grappa Contract Doc

In this doc, we will go through the architecture of the core Grappa system, and the role of each system.

To understand the structure of the repo, please go to [repo guide](./repo-guide.md).

## Architecture


This is the basic diagram of how all contracts interact with each other.

![high level](https://i.imgur.com/DKbsMnU.png)

There are 2 main contracts: `Grappa`, `OptionToken`, and 2 "sets" of contracts: oracles, and margin engines. 

## `Grappa.sol`

`Grappa`: served as a registry for the whole system. Also used for settlement.

## `OptionToken.sol`

`OptionToken`: ERC1155 token that represent the right to claim for a non-negative payout at expiry. It can represent a long call position, a long put position, or debit spreads. How the Id of an option token is interpreted is determined by the Grappa contract at settlement.

## Oracles

Grappa Owner can register bunch of oracles to the system. Oracles are contracts that can be used to determine settlement price, different user / protocol might want to settle with different oracles.

## Margin Engines

**Margine Engines** are contracts that determine the rule to collateralize option tokens. Tokens minted by different engines are not fungible, so that the risk are always isolated. There should be multiple margin engines working together to provide user flexibilities to choose from, based on user preference such as gas fee, capital efficiency, composability and risk.

### List of Margin Engines

- `FullMargin`: fully collateralized margin. can be used to mint:
  - covered call (collateralized with underlying)
  - covered put (collateralized with strike)
  - call spread (collateralized with strike or underlying)
  - put spread (collateralized with strike)
- `CrossMargin`: use a single subAccount to hold multiple long and short positions.
- `AdvancedMargin`(WIP): mint partially collateralized options which is 3x - 20x more capital efficient compared to fully collateralized options. Requires dependencies on vol oracle to estimate the value of option. Each subAccounts can process:
  - single collateral type
  - can mint 1 call (or call spread) + 1 put (or put spread) in a single account.




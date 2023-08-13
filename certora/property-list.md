# Invariant Properties

## Registration

- [x] cannot have duplicated id with same asset, engine or oracle
- [x] id = 0 always return address(0) for asset, engine and oracle

## Get payout

- [ ] calling `getPayout` on valid tokenID can not revert

## Rules

- [ ] cannot mint from un-registered address (engine)
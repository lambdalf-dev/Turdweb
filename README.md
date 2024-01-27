# Turdweb

A tool for people to cheaply migrate their NFT collection.

[Frontend repo](https://github.com/smitch88/thirdweb-migration-fe/tree/main)

## Running the repo

Here's a brief guide as to how run this repo.

First, you make sure you have [foundry](https://github.com/foundry-rs/foundry) on your machine.
Then clone the repo and run:
```
yarn install
forge install
```

### Running the tests

To run the tests, you can run either of the following commands:

- `yarn test` runs the full test suite
- `yarn test:verbose` runs the full test suite, displaying all internal calls, etc...
- `forge test -vvvv --match-test <test case name>` runs a given test case, displaying all internal calls, etc...

### Linting the contracts with forge fmt

To run a linter check, you can run:

- `forge fmt <directory name>` runs forge fmt on the target directory

### Test coverage

To run coverage, run the following commands:

- `yarn coverage` runs a coverage report and generates an html coverage report

### Deployment

To deploy, run the following:

- `yarn deploy:sepolia` deploys on Sepolia testnet
- `yarn deploy:goerli` deploys on Goerli testnet
- `yarn deploy:polygonMumbai` deploys on Mumbai testnet
- `yarn deploy:mainnet` deploys on Ethereum mainnet
- `yarn deploy:polygon` deploys on Polygon mainnet
- `yarn deploy:optimism` deploys on Optimism mainnet

## Contents

- `src`: The list of contracts included in the library.
- `lib`: A list of libraries necessary to run forge test suite.
- `test`: The foundry test suite for the repository.
- `script`: The deployment scripts.

## Testnet deployment

- [Migrated721 implementation](https://goerli.etherscan.io/address/0xF1736E762F7f58D518693E1CdE5111Bbf626dDb3#code)
- [Migrated721 factory](https://goerli.etherscan.io/address/0xC535B94088df301288747d630AF8a346D2f5390D#code)
- [Wrapped721 implementation](https://goerli.etherscan.io/address/0xDf88f75C42574fBa17F3F728b982f91dE4727Ba1#code)
- [Wrapped721 factory](https://goerli.etherscan.io/address/0x2f17b3A6BDb35a59237FE12F4b8EF773341cb9B3#code)

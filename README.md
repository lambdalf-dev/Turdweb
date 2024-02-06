# Shift

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

### Verification

To verify a contract, run the following:

- `forge verify-contract <ADDRESS> <Contract Name> -c <Chain Name>`

## Contents

- `src`: The list of contracts included in the library.
- `lib`: A list of libraries necessary to run forge test suite.
- `test`: The foundry test suite for the repository.
- `script`: The deployment scripts.

## Testnet deployment

- [Factory](https://sepolia.etherscan.io/address/0x064F8943f61Db9c8c870E9b05f6e32042a427ad7#code)
- [Migrated721](https://sepolia.etherscan.io/address/0x8888596f6c3a142A11E408610F2f4560905f3065#code)
- [Wrapped721](https://sepolia.etherscan.io/address/0x9978179a9EE76f6C7ff8BCC1FC8Fb13DF1595f36#code)

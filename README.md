# Uniswap V1 Solidity Implementation

This project implements the core contracts of Uniswap V1 using Solidity 0.8.20 and Hardhat framework.

## Contracts

- `Exchange.sol`: The main exchange contract of Uniswap V1.

- `Factory.sol`: This is a factory to build new exchange contract.

## Usage

1. Install dependencies

```
npm install
```

2. Compile contracts

```
npx hardhat compile
```

3. Deploy contracts on local node

```
npx hardhat run scripts/deploy.js --network localhost
```

4. Run tests

```
npx hardhat test
```

## Acknowledgements

Thanks to Uniswap for providing such a great automated market maker model for us to learn and implement.

Feel free to open issues and PRs!
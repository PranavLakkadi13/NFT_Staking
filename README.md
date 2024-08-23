# The Steps to run this Repo are as follows:

# First You will need to clone the repo by running the following command:
```bash
git clone https://github.com/PranavLakkadi13/NFT_Staking.git
```

## first you need to install the dependencies by running the following command:
```bash
yarn 
```

## Then you can run build the code and get artifacts by running the following command:
```bash
yarn hardhat compile 
forge build 
```

## Then you can deploy the contract by running the following command:
-> This Command will deploy the contract on the local network
```bash
yarn hardhat deploy
```

-> To run the contract on the sepolia network you can run the following command after adding the privatekey in the hardhat.config.js file
```bash
yarn hardhat deploy --network sepolia
```


## To run the tests you can run the following command:
```bash
forge test
```


## To check the code coverage you can run the following command:
```bash
forge coverage
```

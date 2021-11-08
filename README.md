# TOKEN DEPLOYED

<a href="https://polygonscan.com/address/0x76BE864699447062F0dCca614871cE4308890234#code">https://polygonscan.com/address/0x76BE864699447062F0dCca614871cE4308890234#code</a>
<a href="https://rinkeby.etherscan.io/address/0x8A33585619508993FD92664ed8B2c0cb6316069c#code">https://rinkeby.etherscan.io/address/0x8A33585619508993FD92664ed8B2c0cb6316069c#code</a>

# INSTALL DEPENDENCIES

```shell
git clone https://github.com/grape404/RCB-BlockchainAus.git
```

Enter into the the main folder.

```shell
npm install
```

# RUN TEST LOCALLY

```shell
npx hardhat test
```

# CONFIGURE THE DEPLOYMENT

In this project, copy the .env.template file to a file named .env, and then edit it to fill in the details. Enter your Etherscan, Polygonscan API key, your Rinkeby and Matic node URL (eg from Alchemy or Infura), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

Adjust the contract deployment settings!
<b>scripts/deploy.js</b>

To get the Etherscan and Polygonscan API key, go to
<a href="https://etherscan.io/myapikey"> https://etherscan.io/myapikey</a>
<br>
<a href="https://polygonscan.com/myapikey">https://polygonscan.com/myapikey</a>

# DEPLOYMENT & VERIFICATION ON MATIC TESTNET

```shell
npx hardhat run --network rinkeby scripts/deploy.js
```

# DEPLOYMENT & VERIFICATION ON MATIC MAINET

```shell
npx hardhat run --network matic scripts/deploy.js
```

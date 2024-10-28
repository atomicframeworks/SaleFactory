# SaleFactory

**Factory contract to create ERC20 token crowd sales**


## Documentation

### Deploying SaleFactory
**SaleFactory constructor params**
- _initialAuthority `address` - Sets the address of the initial contract owner
- _usdtAddress `address` - USDT contract address
- _usdcAddress `uint256` - USDC contract address
- _priceFeedAddress `uint256` - Chainlink Price feed for ETH/USD price

### Creating a sale
**createSale Params**
- _tokenAddress `address` - ERC20 token address of the token for sale. Assumes an 18 decimal token
- _priceInUsd `uint256` - Price in usd per 1 token (represented with 6 decimals like usdc or usdt)
- _maxTokensToSell `uint256` - Maximum number of tokens to allow for this sale
- _startDate `uint256` - Date to start the sale (unix timestamp in seconds). 0 started as soon as created
- _endDate `uint256` - Date to start the sale (unix timestamp in seconds). 0 is no end date (goes on forever or until max tokens)
- _paused `bool` - Is the sale paused (true) or active (false)
- _tokenTransferCode `TokenTransferCode` -  TokenTransferCode.transfer (0) for transfer, TokenTransferCode.transferFrom (1) for transferFrom, TokenTransferCode.mint (2) for mint
- _transferFromAddress `address` - Address to transfer tokens from if TokenTransferCode is transferFrom.

### Updating a sale
You can update any sale by calling the proper method passing the sale Id and update params

- `setPriceInUsd(uint256 _saleIndex, uint256 _priceInUsd)` - Updates the token price in usd for a sale
- `setMaxTokensToSell(uint256 _saleIndex, uint256 _maxTokensToSell)` -  Updates the token price in USD (6 decimal precision)
- `setStartDate(uint256 _saleIndex, uint256 _startDate)` - Updates the starting date for the sale
- `setEndDate(uint256 _saleIndex, uint256 _endDate)` - Updates the ending date for the sale
- `setTokenAddress(uint256 _saleIndex, address _tokenAddress)` - Updates the address of the token for sale
- `setPausedStatus(uint256 _saleIndex, bool _pausedStatus)` - Pauses/Unpauses the sale

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Anvil

```shell
$ anvil
```

### Deploy SaleFactory to Anvil
```shell
$ make deploy-sale-factory
```

### Deploy SaleFactory to Sepolia

```shell
$ make deploy-sale-factory-sepolia
```

### Deploy SaleFactory to Mainnet

```shell
$ make deploy-sale-factory-mainnet
```

### Deploy mocks to Anvil

```shell
$ deploy-mocks
```

### Deploy mocks to Sepolia

```shell
$ deploy-mocks-sepolia
```

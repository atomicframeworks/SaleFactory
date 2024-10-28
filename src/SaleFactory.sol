// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

// Openzeppelin dependencies
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Chainlink dependencies
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SaleFactory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // An array of 'sale' structs
    Sale[] public sales;

    // USDT & USDC interfaces - used when tokens are purchased with USDT or USDC
    IERC20 public usdtInterface;
    IERC20 public usdcInterface;

    // Price feed interface for ETH/USD
    // https://docs.chain.link/docs/ethereum-addresses/ => (ETH / USD)
    AggregatorV3Interface public priceFeedEthUsdInterface;

    /** @dev Struct details of a sale
        @param tokenAddress ERC20 token address of the token for sale. Assumes is 18 decimal token
        @param tokenTransferMethod: Struct for storing how we will disburse bought tokens (transfer, transferFrom, mint)
        @param priceInUsd Price in usd per 1 token (represented with 6 decimals like usdc or usdt)
        @param maxTokensToSell Maximum number of tokens to sell. 0 is unlimited
        @param tokensSold Number of tokens sold
        @param startDate Date to start the sale (unix timestamp)
        @param endDate Date to start the sale (unix timestamp)
        @param paused is the sale paused or active
     */
    struct Sale {
        address tokenAddress;
        TokenTransferMethod tokenTransferMethod;
        uint256 priceInUsd;
        uint256 maxTokensToSell;
        uint256 tokensSold;
        uint256 startDate;
        uint256 endDate;
        bool paused;
    }

    /**
        @dev Struct for storing how the tokens will be transfered or minted once bought
        @param TransferCode: The token transfer method (transfer, transferFrom, mint)
        @param transferFromAddress: Address that will hold the tokens to transfer from (only used if using transferFrom method)
     */
    struct TokenTransferMethod {
        TokenTransferCode transferCode;
        address transferFromAddress;
    }

    /**
        @dev Codes for methods for different ways of setting the bought token to the individual
        @param transfer: Transfer the token from this SaleManager contract to the buyer (SaleManager must own the tokens)
        @param transferFrom: Transfer the token from another address to the buyer (SaleManager must have approval to transfer the tokens)
        @param mint: Mint the token to the buyer (SaleManager must have Minter approval on the token)
     */
    enum TokenTransferCode {
        transfer,
        transferFrom,
        mint
    }

    /**
        @dev Emitted when tokens are sucessfully bought
     */
    event TokensBought(
        address indexed boughtBy,
        uint256 saleIndex,
        uint256 amount,
        uint256 usdPrice,
        uint256 sentUsd,
        uint256 sentEth,
        bytes32 indexed referralCode
    );

    /**
        @dev Emitted when a sale is created
     */
    event saleCreated(
        uint256 indexed saleIndex,
        address tokenAddress,
        uint256 usdPrice,
        uint256 maxTokensToSell,
        uint256 startDate,
        uint256 endDate,
        TokenTransferCode tokenTransferCode,
        address transferFromAddress
    );

    /**
        @dev Emitted when a sale is updated
     */
    event saleUpdated(
        uint256 indexed saleIndex,
        address tokenAddress,
        uint256 usdPrice,
        uint256 maxTokensToSell,
        uint256 startDate,
        uint256 endDate,
        TokenTransferCode tokenTransferCode,
        address transferFromAddress
    );

    /**
        @dev Makes sure the sale is active
            1. Sale must be 'unpaused'
            2. If there is a start date, it cannot be in the future
            3. If there is an end date, it cannot be in the past
        @param _saleIndex: The index of the sale to adjust
     */
    modifier onlyActiveSale(uint256 _saleIndex) {
        require(sales[_saleIndex].paused == false, "Sale is paused");
        // If there is a start date make sure it's in the past
        if (sales[_saleIndex].startDate != 0) {
            require(
                sales[_saleIndex].startDate <= block.timestamp,
                "Sale date has not started yet"
            );
        }

        // If there is a end date make sure it's in the future
        if (sales[_saleIndex].endDate != 0) {
            require(
                sales[_saleIndex].endDate > block.timestamp,
                "Sale date is over"
            );
        }

        _;
    }

    /**
        @dev Constructor for the SaleManager
        @param _initialAuthority Sets the address of the initial contract owner
        @param _usdtAddress USDT contract address
        @param _usdcAddress USDC contract address
        @param _priceFeedAddress Chainlink Price feed for ETH/USD price
     */
    constructor(
        address _initialAuthority,
        address _usdtAddress,
        address _usdcAddress,
        address _priceFeedAddress
    ) Ownable(_initialAuthority) {
        usdtInterface = IERC20(_usdtAddress);
        usdcInterface = IERC20(_usdcAddress);
        priceFeedEthUsdInterface = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * @notice  Sets the usdtInterface
     * @dev     The interface is used when tokens are purchased with USDT
     * @param   _usdtAddress  Address of USDT token
     */
    function setUsdtInterface(address _usdtAddress) public onlyOwner {
        usdtInterface = IERC20(_usdtAddress);
    }

    /**
     * @notice  Sets the usdcInterface
     * @dev     The interface is used when tokens are purchased with USDC
     * @param   _usdcAddress  Address of USDC token
     */
    function setUsdcInterface(address _usdcAddress) public onlyOwner {
        usdcInterface = IERC20(_usdcAddress);
    }

    /**
     * @notice  Sets the priceFeedEthUsdInterface
     * @dev     The interface is used when tokens are purchased with ETH (ETH/USD rate)
     * @param   _priceFeedAddress  Address for chainlink ETH/USD price feed
     */
    function setPriceFeedEthUsdInterface(
        address _priceFeedAddress
    ) public onlyOwner {
        priceFeedEthUsdInterface = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * @notice Fallbacks to recieve ETH if sent by accident to contract
     */
    receive() external payable {}

    fallback() external payable {}

    /**
     * @notice  Emits a saleUpdated event
     * @dev     Emitted whenever the sale params are updated
     * @param   _saleIndex  Index of the sale that was updated
     */
    function emitSaleUpdated(uint256 _saleIndex) internal {
        emit saleUpdated(
            _saleIndex,
            sales[_saleIndex].tokenAddress,
            sales[_saleIndex].priceInUsd,
            sales[_saleIndex].maxTokensToSell,
            sales[_saleIndex].startDate,
            sales[_saleIndex].endDate,
            sales[_saleIndex].tokenTransferMethod.transferCode,
            sales[_saleIndex].tokenTransferMethod.transferFromAddress
        );
    }

    /**
     * @notice  Create a new sale that will transfer tokens from this contract to the buyer.
     * @dev     If tokenTransferCode is transfer: SaleManager must have a balance of the tokens to transfer
     * @param   _tokenAddress ERC20 token address of the token for sale. Assumes an 18 decimal token
     * @param   _priceInUsd  Price in usd per 1 token (represented with 6 decimals like usdc or usdt)
     * @param   _maxTokensToSell  Maximum number of tokens to allow for this sale
     * @param   _startDate  Date to start the sale (unix timestamp in seconds). 0 started as soon as created
     * @param   _endDate  Date to start the sale (unix timestamp in seconds). 0 is no end date (goes on forever or until max tokens)
     * @param   _paused  Is the sale paused (true) or active (false)
     * @param   _tokenTransferCode  TokenTransferCode.transfer (0) for transfer, TokenTransferCode.transferFrom (1) for transferFrom, TokenTransferCode.mint (2) for mint
     * @param   _transferFromAddress Address to transfer tokens from if TokenTransferCode is transferFrom.
     * @return  uint256  The index of the sale
     */
    function createSale(
        address _tokenAddress,
        uint256 _priceInUsd,
        uint256 _maxTokensToSell,
        uint256 _startDate,
        uint256 _endDate,
        bool _paused,
        TokenTransferCode _tokenTransferCode,
        address _transferFromAddress
    ) public onlyOwner returns (uint256) {
        TokenTransferMethod memory tokenTransferMethod;

        if (_tokenTransferCode == TokenTransferCode.transfer) {
            // If it's a 'transfer' code set the transfer addess as 'this'.
            // For transfer the address isn't used, but it's more accurate since the coins will have to be transferred from this contract
            // This contract will need a balance of the tokens to transfer
            tokenTransferMethod = TokenTransferMethod(
                TokenTransferCode.transfer,
                address(this)
            );
        } else if (_tokenTransferCode == TokenTransferCode.transferFrom) {
            // If it's 'transferFrom' code set the transferFrom address to transfer the from
            // This contract will need to have an 'allowance' of the tokens to transfer
            tokenTransferMethod = TokenTransferMethod(
                TokenTransferCode.transferFrom,
                _transferFromAddress
            );
        } else if (_tokenTransferCode == TokenTransferCode.mint) {
            // If it's a 'mint' code set transfer address to the token address
            // For mint the address isn't used, but it's more accurate since the coins will have to be minted from the token address contract
            // The token will need to be mintable & this contract will need permission to mint
            tokenTransferMethod = TokenTransferMethod(
                TokenTransferCode.mint,
                _tokenAddress
            );
        } else {
            // Error "Not a valid token transfer code"
            require(false, "Not a valid token transfer code");
        }
        sales.push(
            Sale({
                tokenAddress: _tokenAddress,
                tokenTransferMethod: tokenTransferMethod,
                priceInUsd: _priceInUsd,
                maxTokensToSell: _maxTokensToSell,
                tokensSold: 0,
                startDate: _startDate,
                endDate: _endDate,
                paused: _paused
            })
        );
        emit saleCreated(
            sales.length - 1,
            _tokenAddress,
            _priceInUsd,
            _maxTokensToSell,
            _startDate,
            _endDate,
            _tokenTransferCode,
            tokenTransferMethod.transferFromAddress
        );
        return sales.length - 1;
    }

    /**
     * @notice Allows the purchase using USDC
     * @param  _saleIndex The index of the sale to adjust
     * @param  _amountToPurchase Amount of new token to buy
     * @param  _referralCode Referral code for the purchase if traking referrals
     */
    function buyWithUsdc(
        uint256 _saleIndex,
        uint256 _amountToPurchase,
        bytes32 _referralCode
    ) public {
        require(
            address(usdcInterface) != address(0),
            "USDC contract address must be set"
        );

        buyWithUsdToken(
            _saleIndex,
            usdcInterface,
            _amountToPurchase,
            _referralCode
        );
    }

    /**
     * @notice  Allows the purchase using USDT
     * @param   _saleIndex   The index of the sale to purchase tokens from
     * @param   _amountToPurchase  Amount of new token to buy
     * @param   _referralCode  Referral code for the purchase if traking referrals
     */
    function buyWithUsdt(
        uint256 _saleIndex,
        uint256 _amountToPurchase,
        bytes32 _referralCode
    ) public {
        require(
            address(usdtInterface) != address(0),
            "USDT contract address must be set"
        );

        buyWithUsdToken(
            _saleIndex,
            usdtInterface,
            _amountToPurchase,
            _referralCode
        );
    }

    /**
     * @notice  Attempts to purchase the new token with an erc20 token that is USDC or USDT
     * @dev     USDT/USDC are 6 decimals precision
     * @param   _saleIndex   The index of the sale to purchase tokens from
     * @param   _purchaseTokenInterface  ERC20 token interface used to purchase (either USDT or USDC)
     * @param   _amountToPurchase  Amount of new token to buy
     * @param   _referralCode  Referral code for the purchase if traking referrals
     */
    function buyWithUsdToken(
        uint256 _saleIndex,
        IERC20 _purchaseTokenInterface,
        uint256 _amountToPurchase,
        bytes32 _referralCode
    ) internal onlyActiveSale(_saleIndex) nonReentrant {
        require(_amountToPurchase > 0, "Must purchase more than 0 tokens");

        // Cost of buying x amount (18 decimals) of token times purchase price (6 decimals) per token
        uint256 usdPurchasePrice = (_amountToPurchase *
            sales[_saleIndex].priceInUsd) / 1e18;

        // Avoid rounding 0 errors from trying to purchase too little
        require(usdPurchasePrice > 0, "Amount too small to process");

        // Get the token allowance for our contract (ex. how many tokens the person has granted to contract for a purchase)
        uint256 tokenAllowance = _purchaseTokenInterface.allowance(
            _msgSender(),
            address(this)
        );

        // Max sure we aren't selling more than max tokens
        if (sales[_saleIndex].maxTokensToSell > 0) {
            require(
                _amountToPurchase <=
                    sales[_saleIndex].maxTokensToSell -
                        sales[_saleIndex].tokensSold,
                "Purchase amount exceeds tokens available for sale"
            );
        }

        // Make sure that they gave us enough 'allowance' aka usdt/usdc for purchasing the new token
        require(
            usdPurchasePrice <= tokenAllowance,
            "Make sure to add enough allowance"
        );

        // Transfer the USD token used to buy the token
        _purchaseTokenInterface.safeTransferFrom(
            _msgSender(),
            owner(),
            usdPurchasePrice
        );

        // Transfer the tokens to the purchaser
        transferTokensToPurchaser(_saleIndex, _amountToPurchase);

        // Track the number of tokens sold
        sales[_saleIndex].tokensSold =
            sales[_saleIndex].tokensSold +
            _amountToPurchase;
        emit TokensBought(
            _msgSender(),
            _saleIndex,
            _amountToPurchase,
            sales[_saleIndex].priceInUsd,
            usdPurchasePrice,
            0,
            _referralCode
        );
    }

    /**
     * @notice  Attempts to purchase the new token with  Eth
     * @dev     ETH value is 18 decimal precision
     * @param   _saleIndex  The index of the sale to purchase tokens from
     * @param   _referralCode  Referral code for the purchase if traking referrals
     */
    function buyWithEth(
        uint256 _saleIndex,
        bytes32 _referralCode
    ) public payable onlyActiveSale(_saleIndex) nonReentrant {
        require(msg.value > 0, "Must send more than 0 eth");

        // Get the price feed data for eth/usd
        (, int256 answer, , , ) = priceFeedEthUsdInterface.latestRoundData();
        require(answer > 0, "Invalid price feed answer");

        uint256 ethToUsdRate = uint256(answer); // Answer is in 8 decimals

        // Get the price of the token in USD
        uint256 tokenPriceInUsd = sales[_saleIndex].priceInUsd; // Token price in 6 decimals

        // Calculate usd value sent
        uint256 usdValueSent = (msg.value * ethToUsdRate) / 1e8; // Convert ETH sent to USD (result in 18 decimals)

        // Calculate the amount of tokens to be received
        uint256 _amountToPurchase = (usdValueSent * 1e6) / tokenPriceInUsd; // Convert USD value to tokens (result in 18 decimals)

        // Avoid rounding 0 errors from trying to purchase too little
        require(_amountToPurchase > 0, "Amount too small to process");

        // Max sure we aren't selling more than max tokens
        if (sales[_saleIndex].maxTokensToSell > 0) {
            require(
                _amountToPurchase <=
                    sales[_saleIndex].maxTokensToSell -
                        sales[_saleIndex].tokensSold,
                "Purchase amount exceeds tokens available for sale"
            );
        }

        payable(owner()).transfer(msg.value);

        // Transfer the tokens to the purchaser
        transferTokensToPurchaser(_saleIndex, _amountToPurchase);

        // Track the number of tokens sold
        sales[_saleIndex].tokensSold =
            sales[_saleIndex].tokensSold +
            _amountToPurchase;

        emit TokensBought(
            _msgSender(),
            _saleIndex,
            _amountToPurchase,
            sales[_saleIndex].priceInUsd,
            0,
            msg.value,
            _referralCode
        );
    }

    /**
     * @notice  Transfers the bought tokens to the purchaser
     * @dev     Called by buyWithUsdToken or buyWithEth after confirming usdc,usdt, or ETH has been received
     * @param   _saleIndex  The index of the sale to send tokens from
     * @param   _amountToPurchase Amount of new token to send
     */
    function transferTokensToPurchaser(
        uint256 _saleIndex,
        uint256 _amountToPurchase
    ) internal {
        Sale memory sale = sales[_saleIndex];

        // Attempt the transfer of bought tokens to buyer using the function call (transfer, transferFrom, or mint)
        // Check to see how are we distributing bought tokens (transfer, transferFrom, mint)
        if (
            sale.tokenTransferMethod.transferCode == TokenTransferCode.transfer
        ) {
            // If the transfer code is 'transfer' then transfer the tokens from this contract to the buyer
            IERC20(sale.tokenAddress).safeTransfer(
                _msgSender(),
                _amountToPurchase
            );
        } else if (
            sale.tokenTransferMethod.transferCode ==
            TokenTransferCode.transferFrom
        ) {
            // If the transfer code is 'transferFrom' then transfer the tokens from another address to the buyer
            IERC20(sale.tokenAddress).safeTransferFrom(
                sale.tokenTransferMethod.transferFromAddress,
                _msgSender(),
                _amountToPurchase
            );
        } else if (
            sale.tokenTransferMethod.transferCode == TokenTransferCode.mint
        ) {
            // If the transfer code is 'mint' then mint the tokens to the buyer
            (bool success, ) = address(sale.tokenAddress).call(
                abi.encodeWithSignature(
                    "mint(address,uint256)",
                    _msgSender(),
                    _amountToPurchase
                )
            );
            require(success, "Token mint failed");
        }
    }

    /**
     * @notice  Updates the token price in usd for a sale
     * @param   _saleIndex  Index of the sale to update
     * @param   _priceInUsd  Price in usd per 1 token (whole dollars only currently)
     */
    function setPriceInUsd(
        uint256 _saleIndex,
        uint256 _priceInUsd
    ) public onlyOwner {
        sales[_saleIndex].priceInUsd = _priceInUsd;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice  Updates the token price in USD (6 decimal precision)
     * @param   _saleIndex  The index of the sale to update
     * @param   _maxTokensToSell  maximum tokens to sell. 0 is unlimited
     */
    function setMaxTokensToSell(
        uint256 _saleIndex,
        uint256 _maxTokensToSell
    ) public onlyOwner {
        sales[_saleIndex].maxTokensToSell = _maxTokensToSell;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice  Updates the starting date for the sale
     * @param   _saleIndex  he index of the sale to update
     * @param   _startDate  unix timestamp in seconds for the start date
     */
    function setStartDate(
        uint256 _saleIndex,
        uint256 _startDate
    ) public onlyOwner {
        sales[_saleIndex].startDate = _startDate;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice Updates the ending date for the sale
     * @param  _saleIndex: The index of the sale to adjust
     * @param  _endDate: unix timestamp for the end date
     */
    function setEndDate(uint256 _saleIndex, uint256 _endDate) public onlyOwner {
        sales[_saleIndex].endDate = _endDate;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice  Updates the address of the token for sale
     * @param   _saleIndex  Index of the sale to update
     * @param   _tokenAddress  Address of the token to sell
     */
    function setTokenAddress(
        uint256 _saleIndex,
        address _tokenAddress
    ) public onlyOwner {
        sales[_saleIndex].tokenAddress = _tokenAddress;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice  Pauses/Unpauses the sale
     * @param   _saleIndex  The index of the sale to update
     * @param   _pausedStatus True = paused, false = not paused
     */
    function setPausedStatus(
        uint256 _saleIndex,
        bool _pausedStatus
    ) public onlyOwner {
        sales[_saleIndex].paused = _pausedStatus;
        emitSaleUpdated(_saleIndex);
    }

    /**
     * @notice  Allows withdrawl of any erc20 that gets sent to this contract by accident
     * @param   tokenAddress  Token contract address to withdraw
     * @param   amount  Amount to withdraw
     */
    function withdrawERC20Token(
        address tokenAddress,
        uint256 amount
    ) public onlyOwner {
        IERC20(tokenAddress).safeTransfer(_msgSender(), amount);
    }

    /**
     * @notice  Allows withdrawl of any ETH that gets sent to this contract by accident
     */
    function withdrawEth() external onlyOwner {
        (bool success, ) = _msgSender().call{value: address(this).balance}("");
        require(success, "Withdraw ETH failed.");
    }
}

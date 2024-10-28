// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

// Chainlink price feed interface
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// ERC20 interface
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// SaleFactory Script
import {SaleFactory} from "../src/SaleFactory.sol";

// Helper Scripts
import {HelperConfig} from "../script/HelperConfig.s.sol";

// Mocks for tokens: USDT, USDC, and an ERC20 (which will be the sale token)
import {MockUsdt} from "./mocks/MockUsdt.sol";
import {MockUsdc} from "./mocks/MockUsdc.sol";
import {MockErc20} from "./mocks/MockErc20.sol";

contract TestSaleFactory is Test {
    // Mock USDT, USDC, & ERC20 tokens for testing
    IERC20 public mockUsdt;
    IERC20 public mockUsdc;
    IERC20 public mockErc20;

    // The SaleFactory contract which we will test
    SaleFactory public saleFactory;

    // Addresses for testing users and owners
    address SALE_TOKEN_OWNER = makeAddr("ERC20 test sale token owner");
    address NOT_OWNER = makeAddr("Not an owner of anything");

    // Owners of mock tokens
    address USDT_OWNER = makeAddr("USDT Owner");
    address USDC_OWNER = makeAddr("USDC Owner");
    address ERC20_OWNER = makeAddr("ERC20 Owner");

    // Total amount of the ERC20
    uint256 ERC20_TOTAL_SUPPLY = 1000000 * 1e18;

    // USDC/USDT mint amount
    uint256 USD_MINT_AMOUNT = 1000000 * 1e18;

    function setUp() public {
        // The initial owner of the saleFactory contract
        address INITIAL_OWNER = address(this);

        // Ignoring the the usdc and usdt addresses in the helper config so we can manage them here
        HelperConfig helperConfig = new HelperConfig();
        (, , address _priceFeedAddress) = helperConfig.activeNetworkConfig();

        // Create Mock USDT
        vm.prank(USDT_OWNER);
        mockUsdt = new MockUsdt();
        // Deal some eth to the USDT Owner
        vm.deal(USDT_OWNER, 1 ether);

        // Create Mock USDC
        vm.prank(USDC_OWNER);
        mockUsdc = new MockUsdc();
        // Deal some eth to the USDT Owner
        vm.deal(USDC_OWNER, 1 ether);

        // Create Mock ERC20 (will be used as the sale token)
        vm.prank(ERC20_OWNER);
        mockErc20 = new MockErc20();
        // Deal some eth to the ERC20 Owner
        vm.deal(ERC20_OWNER, 1 ether);

        saleFactory = new SaleFactory(
            INITIAL_OWNER,
            address(mockUsdt),
            address(mockUsdc),
            _priceFeedAddress
        );
    }

    // Create a new sale with some default settings
    // Returns the sale index of the created sale
    function createNewSaleTransfer() public returns (uint256) {
        address _saleTokenAddress = address(mockErc20);
        uint256 _maxTokensToSell = 0;
        uint256 _priceInUsd = 1;
        uint256 _startDate = 0;
        uint256 _endDate = 0;
        bool _paused = false;
        uint256 saleIndex = saleFactory.createSale(
            _saleTokenAddress,
            _priceInUsd,
            _maxTokensToSell,
            _startDate,
            _endDate,
            _paused,
            SaleFactory.TokenTransferCode.transfer,
            address(0)
        );

        // Since it is a sale 'transfer' we expect the saleFactory contract to have some ERC20
        // Transfer some Mock ERC20 token to the saleFactory, so it can use it via transfer
        vm.prank(ERC20_OWNER);
        mockErc20.transfer(address(saleFactory), ERC20_TOTAL_SUPPLY);

        return saleIndex;
    }

    /**
        @dev Creates a new saleFactory with TransferFrom method as disbursement
        Note: The address we are transfering tokens from is the usdc_owner. This means usdc_owner needs to give allowance to usdc_owner
     */
    function createNewSaleTransferFrom() public returns (uint256) {
        address _saleTokenAddress = address(mockErc20);
        address _saleTokenTransferFromAddress = address(ERC20_OWNER);
        uint256 _maxTokensToSell = 0;
        uint256 _priceInUsd = 1;
        uint256 _startDate = 0;
        uint256 _endDate = 0;
        bool _paused = true;
        uint256 saleIndex = saleFactory.createSale(
            _saleTokenAddress,
            _priceInUsd,
            _maxTokensToSell,
            _startDate,
            _endDate,
            _paused,
            SaleFactory.TokenTransferCode.transferFrom,
            _saleTokenTransferFromAddress
        );

        return saleIndex;
    }

    /**
        @dev Creates a new saleFactory with mint method as disbursement
        Note: The address we are minting tokens from is the _saleToken_Address
     */
    function createNewSaleMint() public returns (uint256) {
        address SALE_TOKEN_ADDRESS = address(mockErc20);
        uint256 PRICE_IN_USD = 1;
        uint256 MAX_TOKENS_TO_SELL = 0;
        uint256 START_DATE = 0;
        uint256 END_DATE = 0;
        bool PAUSED = true;
        // The address doesn't matter for a mint, since the factory uses the sale_token_address because it mints from that contract
        address RANDOM_ADDRESS = makeAddr("Random address");

        uint256 saleIndex = saleFactory.createSale(
            SALE_TOKEN_ADDRESS,
            PRICE_IN_USD,
            MAX_TOKENS_TO_SELL,
            START_DATE,
            END_DATE,
            PAUSED,
            SaleFactory.TokenTransferCode.mint,
            RANDOM_ADDRESS
        );

        return saleIndex;
    }

    function test_can_set_token_price_in_usd() public {
        uint256 NEW_PRICE_IN_USD = 100;

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the new price
        saleFactory.setPriceInUsd(_saleIndex, NEW_PRICE_IN_USD);

        // Get the price and assert it equals the nice price
        (, , uint256 _priceInUsd, , , , , ) = saleFactory.sales(_saleIndex);
        assertEq(_priceInUsd, NEW_PRICE_IN_USD);
    }

    function test_can_purchase_with_usdc() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // USD allowance to spend
        uint256 USD_ALLOWANCE = 100 * 1e6;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Approve usdc tokens for the saleFactory contract to have
        vm.prank(USDC_OWNER);
        mockUsdc.approve(address(saleFactory), USD_ALLOWANCE);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Attempt to buy new 100 tokens using 100 erc20 token
        vm.prank(USDC_OWNER);
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get the amount purchased and assert it equals the amount we wanted to buy
        uint256 _tokensPurchased = mockErc20.balanceOf(USDC_OWNER);
        assertEq(AMOUNT_TO_PURCHASE, _tokensPurchased);
    }

    function test_can_purchase_with_usdc_decimals() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 1 * 1e18;
        // Price per token 1.5 USD
        uint256 PRICE_IN_USD = 15 * 1e5;
        // USD allowance to spend - 1.5 usd allowance, purchase 1 token @ cost of 1.5 usd per
        uint256 USD_ALLOWANCE = 15 * 1e5;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        uint256 _saleIndex = createNewSaleTransfer();

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Approve usdc tokens for the saleFactory contract to have
        vm.prank(USDC_OWNER);
        mockUsdc.approve(address(saleFactory), USD_ALLOWANCE);

        // Attempt to buy new 100 tokens using 100 erc20 token
        vm.prank(USDC_OWNER);
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get the amount purchased and assert its equal to what we wanted to purchase
        uint256 _tokensPurchased = mockErc20.balanceOf(USDC_OWNER);
        assertEq(AMOUNT_TO_PURCHASE, _tokensPurchased);
    }

    function test_can_purchase_with_usdt() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // USD allowance to spend
        uint256 USD_ALLOWANCE = 100 * 1e6;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Approve usdt tokens for the saleFactory contract to have
        vm.prank(USDT_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Attempt to buy new 100 tokens using 100 erc20 token
        vm.prank(USDT_OWNER);
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        uint256 _tokensPurchased = mockErc20.balanceOf(USDT_OWNER);

        assertEq(AMOUNT_TO_PURCHASE, _tokensPurchased);
    }

    function test_can_disburse_with_transfer_from() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // USD allowance to spend: $100 (meaning we gave saleFactory $100 to spend for us on the new token)
        uint256 USD_ALLOWANCE = 100 * 1e6;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransferFrom();

        // Approve USD for the saleFactory contract to spend (to buy the erc20)
        vm.prank(USDT_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Approve the sale factory to transfer some of the mock erc20 FROM the erc20 owner (this is because we are using transferFrom)
        vm.prank(ERC20_OWNER);
        mockErc20.approve(address(saleFactory), AMOUNT_TO_PURCHASE);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Attempt to buy new 100 tokens using 100 erc20 token
        vm.prank(USDT_OWNER);
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get and assert the tokens we purchased match the amount we wanted to buy
        uint256 _tokensPurchased = mockErc20.balanceOf(USDT_OWNER);
        assertEq(AMOUNT_TO_PURCHASE, _tokensPurchased);
    }

    function test_can_disburse_with_mint() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // USD allowance to spend
        uint256 USD_ALLOWANCE = 100 * 1e6;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleMint();

        // Approve usdt tokens for the saleFactory contract to have
        vm.prank(USDT_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Attempt to buy new 100 tokens using 100 erc20 token
        vm.prank(USDT_OWNER);
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
        vm.stopPrank();

        // Get and assert the tokens we purchased match the amount we wanted to buy
        uint256 tokensPurchased = mockErc20.balanceOf(USDT_OWNER);
        assertEq(AMOUNT_TO_PURCHASE, tokensPurchased);
    }

    function test_can_purchase_with_usdt_fails_paused_sale() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Pause the sale
        saleFactory.setPausedStatus(_saleIndex, true);

        // Attempt to buy tokens and expect to revert since it's paused
        vm.prank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
    }

    function test_can_purchase_with_usdc_fails_paused_sale() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Pause the sale
        saleFactory.setPausedStatus(_saleIndex, true);

        // Attempt to buy tokens and expect it to revert since it's paused
        vm.prank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
    }

    function test_can_purchase_with_usd_fails_allowance() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 10 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // USD allowance to spend (less than needed)
        uint256 USD_ALLOWANCE = 1 * 1e6;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Approve usdc tokens for the saleFactory contract to have
        vm.prank(USDC_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Get original balance
        uint256 _originalTokenBalance = mockErc20.balanceOf(USDC_OWNER);

        // Attempt to buy new 100 tokens using 100 erc20 token nd expect it to revert since allowance is 1
        vm.expectRevert();
        vm.prank(USDC_OWNER);
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get and assert the tokens we purchased match the original balance
        uint256 _tokensPurchased = mockErc20.balanceOf(USDC_OWNER);
        assertEq(_originalTokenBalance, _tokensPurchased);
    }

    function test_start_date_in_future_fails() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Set the start date 3 days in the future
        saleFactory.setStartDate(_saleIndex, block.timestamp + 3 days);

        // Attempt to buy tokens and expect to revert since the start date is in the future
        vm.prank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
    }

    function test_end_date_in_past_fails() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the sale to be active
        saleFactory.setPausedStatus(_saleIndex, false);

        // Set the VM timestamp
        vm.warp(3);
        // Set end date to 1
        saleFactory.setEndDate(_saleIndex, 1);

        // Attempt to buy tokens and expect to revert since the end date is in the past
        vm.prank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
    }

    function test_can_pause_and_unpause_a_sale() public {
        // Create a new sale
        uint256 saleIndex = createNewSaleTransfer();

        // Set the sale to be active (sale paused is false)
        saleFactory.setPausedStatus(saleIndex, false);

        // Get the paused status and assert it's false
        (, , , , , , , bool _paused) = saleFactory.sales(saleIndex);
        assertFalse(_paused);

        // Set the sale to be paused (sale paused is true)
        saleFactory.setPausedStatus(saleIndex, true);

        // Get the paused status and assert it's true
        (, , , , , , , _paused) = saleFactory.sales(saleIndex);
        assertTrue(_paused);
    }

    function test_creating_sale_sets_usdt_and_usdc() public view {
        assertEq(address(saleFactory.usdtInterface()), address(mockUsdt));
        assertEq(address(saleFactory.usdcInterface()), address(mockUsdc));
    }

    function test_can_set_maximum_tokens_to_sell() public {
        // Amount of max tokens to sell
        uint256 NEW_MAX_TOKENS_TO_SELL = 100 * 1e18;

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the new max tokens to sell
        saleFactory.setMaxTokensToSell(_saleIndex, NEW_MAX_TOKENS_TO_SELL);

        // Get the max tokens to sell and assert they are equal to the new number
        (, , , uint256 _maxTokensToSell, , , , ) = saleFactory.sales(
            _saleIndex
        );
        assertEq(_maxTokensToSell, NEW_MAX_TOKENS_TO_SELL);
    }

    function test_cant_buy_more_than_maximum() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 101 * 1e16;
        // Price per token
        uint256 PRICE_IN_USD = 1;
        // USD allowance to spend: $100 (meaning we gave saleFactory $100 to spend for us on the new token)
        uint256 USD_ALLOWANCE = 1000 * 1e6;
        // Amount of max tokens to sell
        uint256 MAX_TOKENS_TO_SELL = 100 * 1e16;
        // Referral code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();
        saleFactory.setMaxTokensToSell(_saleIndex, MAX_TOKENS_TO_SELL);

        // Approve usdt tokens for the saleFactory contract to have
        vm.prank(USDC_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        uint256 initialBalance = mockUsdt.balanceOf(address(USDC_OWNER));

        // Attempt to buy 101 new tokens and expect it to fail since the max is 100 tokens
        vm.prank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get the tokens purchase and make sure it matches initial balance (no new tokens)
        uint256 _tokensPurchased = mockErc20.balanceOf(USDC_OWNER);
        assertEq(initialBalance, _tokensPurchased);
    }

    function test_cant_buy_more_than_maximum_after_it_zeros() public {
        // Max number to sell is same amount we want to purchase
        uint256 MAX_TOKENS_TO_SELL = 100 * 1e18;
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = MAX_TOKENS_TO_SELL;
        // An extra / 2nd amount to purchase
        uint256 EXTRA_AMOUNT_TO_PURCHASE = 2 * 1e18;
        // Price per token
        uint256 PRICE_IN_USD = 1 * 1e6;
        // Usd allowance to spend (more than we need)
        uint256 USD_ALLOWANCE = 1000 * 1e6;
        // Referall code for purchase
        bytes32 REFERRAL_CODE = "";

        uint256 _saleIndex = createNewSaleTransfer();

        // Se the maxiumum number of tokens to sell
        saleFactory.setMaxTokensToSell(_saleIndex, MAX_TOKENS_TO_SELL);

        // Set the usd token price
        saleFactory.setPriceInUsd(_saleIndex, PRICE_IN_USD);

        // Approve usdt tokens for the saleFactory contract to have
        vm.prank(USDT_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Buy all new tokens
        vm.prank(USDT_OWNER);
        saleFactory.buyWithUsdt(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);

        // Get the tokens purchased and assert it matches the max tokens to sell
        uint256 _tokensPurchased = mockErc20.balanceOf(USDT_OWNER);
        assertEq(MAX_TOKENS_TO_SELL, _tokensPurchased);

        // Try to buy a few more (and expect a revert)
        vm.startPrank(USDT_OWNER);
        vm.expectRevert();
        saleFactory.buyWithUsdt(
            _saleIndex,
            EXTRA_AMOUNT_TO_PURCHASE,
            REFERRAL_CODE
        );
    }

    function test_can_buy_exactly_maximum() public {
        // Allowance of 1000 USD
        uint256 USD_ALLOWANCE = 1000 * 1e6;
        // Amount to purchase is 100 tokens
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // Price per token 0.000001 (usd token has 6 decimals)
        uint256 PRICE_IN_USD = 1;
        // Max number to sell is same amount we want to purchase
        uint256 MAX_TOKENS_TO_SELL = AMOUNT_TO_PURCHASE;

        // Create a new sale
        uint256 saleIndex = createNewSaleTransfer();

        // Set the max number to sell
        saleFactory.setMaxTokensToSell(saleIndex, MAX_TOKENS_TO_SELL);

        //  Approve usdt tokens for the saleFactory contract to have
        vm.prank(USDT_OWNER);
        mockUsdt.approve(address(saleFactory), USD_ALLOWANCE);

        // Set the usd token price
        saleFactory.setPriceInUsd(saleIndex, PRICE_IN_USD);

        // Attempt to buy new tokens using 100 usdt
        vm.prank(USDT_OWNER);
        saleFactory.buyWithUsdt(saleIndex, AMOUNT_TO_PURCHASE, bytes32(""));

        // Check that our total purchased is same as the amount to purchase
        uint256 _tokensPurchased = mockErc20.balanceOf(USDT_OWNER);
        assertEq(AMOUNT_TO_PURCHASE, _tokensPurchased);

        // Check that the total tokens sold is the same as amount to purchase
        (, , , , uint256 _tokensSold, , , ) = saleFactory.sales(saleIndex);
        assertEq(_tokensSold, AMOUNT_TO_PURCHASE);
    }

    function test_can_withdrawERC20Token() public {
        vm.startPrank(USDT_OWNER);
        uint256 initialBalance = mockUsdt.balanceOf(address(USDT_OWNER));
        uint256 amountToTransfer = 100000;
        mockUsdt.transfer(address(saleFactory), amountToTransfer);
        vm.stopPrank();

        // Assert the balance was transferred out
        assertEq(
            mockUsdt.balanceOf(address(USDT_OWNER)),
            initialBalance - amountToTransfer
        );
        // Assert the saleFactory manager got the transferred balance
        assertEq(amountToTransfer, mockUsdt.balanceOf(address(saleFactory)));
        // Withdraw the balance
        saleFactory.withdrawERC20Token(address(mockUsdt), amountToTransfer);
        // Assert that the balance has been withdrawn
        assertEq(mockUsdt.balanceOf(address(this)), amountToTransfer);
    }

    /**
        Receive needed for this test contract so the test contract can get eth sent to it
     */
    receive() external payable {}

    function test_can_withdraw_eth() public {
        uint256 initialBalance = address(this).balance;
        uint256 ethAmount = 1 ether;
        payable(address(saleFactory)).transfer(ethAmount);
        // Assert the saleFactory manager got the transferred eth
        assertEq(address(saleFactory).balance, ethAmount);
        // Assert we sent the eth
        assertEq(address(this).balance, initialBalance - ethAmount);
        // Withdraw the eth
        saleFactory.withdrawEth();
        // Assert that the balance has been withdrawn
        assertEq(address(this).balance, initialBalance);
    }

    function test_can_create_sale() public {
        address _saleTokenAddress = address(mockErc20);
        uint256 _maxTokensToSell = 0;
        uint256 _priceInUsd = 1;
        uint256 _startDate = 0;
        uint256 _endDate = 0;
        bool _paused = false;

        uint256 saleIndex = saleFactory.createSale(
            _saleTokenAddress,
            _priceInUsd,
            _maxTokensToSell,
            _startDate,
            _endDate,
            _paused,
            SaleFactory.TokenTransferCode.transfer,
            address(0)
        );
        assertEq(saleIndex, 0);
    }

    function test_can_buy_tokens_with_eth() public {
        // The amount of eth to send for purchase
        uint256 SEND_VALUE = 0.1 ether;
        // USD price per one token
        uint256 USD_PRICE_PER_TOKEN = 10 * 1e6;
        // Max amount of tokens to sell (1 million / total supply )
        uint256 MAX_TOKENS_TO_SELL = 1000000 * 1e18;
        // Referall code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the max tokens to sell (1 mil / total supply)
        saleFactory.setMaxTokensToSell(_saleIndex, MAX_TOKENS_TO_SELL);

        // Set the price per token
        saleFactory.setPriceInUsd(_saleIndex, USD_PRICE_PER_TOKEN);

        // Get the price feed data for eth/usd
        (, int256 answer, , , ) = saleFactory
            .priceFeedEthUsdInterface()
            .latestRoundData();
        require(answer > 0, "Invalid price feed answer");
        uint256 ethToUsdRate = uint256(answer); // Answer is in 8 decimals

        // Get the price of the token in USD
        (, , uint256 tokenPriceInUsd, , , , , ) = saleFactory.sales(_saleIndex);

        // Calculate usd value sent
        uint256 usdValueSent = (SEND_VALUE * ethToUsdRate) / 1e8; // Convert ETH sent to USD (result in 18 decimals)

        // Calculate the amount of tokens that should be received
        uint256 _amountToPurchase = (usdValueSent * 1e6) / tokenPriceInUsd; // Convert USD value to tokens (result in 18 decimals)

        // Buy some tokens using eth
        vm.prank(USDC_OWNER);
        saleFactory.buyWithEth{value: SEND_VALUE}(_saleIndex, REFERRAL_CODE);

        // Get the number of tokens purchased and assert it's equal to the amount we wanted to buy
        uint256 tokensPurchased = mockErc20.balanceOf(USDC_OWNER);
        assertEq(tokensPurchased, _amountToPurchase);
    }

    function test_cant_buy_over_max_tokens_with_eth() public {
        // The amount of eth to send for purchase
        uint256 SEND_VALUE = 0.1 ether;
        // USD price per one token
        uint256 USD_PRICE_PER_TOKEN = 10 * 1e6;
        // Max amount of tokens to sell (1 token so we max quickly)
        uint256 MAX_TOKENS_TO_SELL = 1 * 1e18;
        // Referall code for purchase
        bytes32 REFERRAL_CODE = "";

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the max tokens to sell (1 mil / total supply)
        saleFactory.setMaxTokensToSell(_saleIndex, MAX_TOKENS_TO_SELL);

        // Set the price per token
        saleFactory.setPriceInUsd(_saleIndex, USD_PRICE_PER_TOKEN);

        // Try to buy more tokens than is allowed for sale and expect a revert
        vm.expectRevert();
        saleFactory.buyWithEth{value: SEND_VALUE}(_saleIndex, REFERRAL_CODE);
    }

    function test_can_change_token_address() public {
        address NEW_ERC20_TOKEN_ADDRESS = makeAddr("New ERC20 Token Address");

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the new token address
        saleFactory.setTokenAddress(_saleIndex, NEW_ERC20_TOKEN_ADDRESS);

        // Get the token address and assert it equals the new token address
        (address _tokenAddress, , , , , , , ) = saleFactory.sales(_saleIndex);
        assertEq(_tokenAddress, NEW_ERC20_TOKEN_ADDRESS);
    }

    function test_only_owner_can_set_everything() public {
        address NEW_ADDRESS = makeAddr("A new address");
        uint256 NEW_MAX_TOKENS_TO_SELL = 1000000;
        uint256 NEW_PRICE_IN_USD = 250000;
        uint256 NEW_START_DATE = 1000;
        uint256 NEW_END_DATE = 2000;
        bool NEW_PAUSED = true;

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Start a prank as NOT the sale factory owner, attempt to set everything and expect it all to fail
        vm.startPrank(USDC_OWNER);
        vm.expectRevert();
        saleFactory.setTokenAddress(_saleIndex, NEW_ADDRESS);
        vm.expectRevert();
        saleFactory.setMaxTokensToSell(_saleIndex, NEW_MAX_TOKENS_TO_SELL);
        vm.expectRevert();
        saleFactory.setPriceInUsd(_saleIndex, NEW_PRICE_IN_USD);
        vm.expectRevert();
        saleFactory.setStartDate(_saleIndex, NEW_START_DATE);
        vm.expectRevert();
        saleFactory.setEndDate(_saleIndex, NEW_END_DATE);
        vm.expectRevert();
        saleFactory.setPausedStatus(_saleIndex, NEW_PAUSED);
        vm.expectRevert();
        saleFactory.setUsdcInterface(NEW_ADDRESS);
        vm.expectRevert();
        saleFactory.setUsdtInterface(NEW_ADDRESS);
        vm.expectRevert();
        saleFactory.setPriceFeedEthUsdInterface(NEW_ADDRESS);
        vm.stopPrank();
    }

    function test_only_owner_gets_eth_on_purchase() public {
        // The amount of eth to send for purchase
        uint256 SEND_VALUE = 0.1 ether;
        // USD price per one token
        uint256 USD_PRICE_PER_TOKEN = 10 * 1e6;
        // Max amount of tokens to sell (1 mil / total supply)
        uint256 MAX_TOKENS_TO_SELL = 1000000 * 1e18;
        // Referall code for purchase
        bytes32 REFERRAL_CODE = "";
        // Address of the new saleFactory owner
        address NEW_SALE_FACTORY_OWNER = makeAddr("New saleFactory owner");
        address ORIGNIAL_SALE_FACTORY_OWNER = address(this);

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the max tokens to sell (1 mil / total supply)
        saleFactory.setMaxTokensToSell(_saleIndex, MAX_TOKENS_TO_SELL);

        // Set the price per token
        saleFactory.setPriceInUsd(_saleIndex, USD_PRICE_PER_TOKEN);

        // Transfer ownership to the new owner
        saleFactory.transferOwnership(NEW_SALE_FACTORY_OWNER);

        // Initial balance of the original saleFactory owner
        uint256 _initialBalanceOrignalOwner = ORIGNIAL_SALE_FACTORY_OWNER
            .balance;
        // Initial balance of the new sale factory owner
        uint256 _initialBalanceNewOwner = NEW_SALE_FACTORY_OWNER.balance;

        // Buy some tokens using eth
        saleFactory.buyWithEth{value: SEND_VALUE}(_saleIndex, REFERRAL_CODE);

        // Make sure the new owner got the balance
        assertEq(
            NEW_SALE_FACTORY_OWNER.balance,
            _initialBalanceNewOwner + SEND_VALUE
        );

        // Make sure balance of the original owner is less the amount it sent to buy
        assertEq(
            ORIGNIAL_SALE_FACTORY_OWNER.balance,
            _initialBalanceOrignalOwner - SEND_VALUE
        );
    }

    function test_only_owner_gets_usdc_on_purchase() public {
        // Amount of tokens to purchase
        uint256 AMOUNT_TO_PURCHASE = 100 * 1e18;
        // USD price per one token
        uint256 USD_PRICE_PER_TOKEN = 1 * 1e6;
        // USD allowance to spend ($100 = 100 tokens to purchase x $1 per token)
        uint256 USD_ALLOWANCE = 100 * 1e6;
        // Referall code for purchase
        bytes32 REFERRAL_CODE = "";
        // Address of the new saleFactory owner
        address NEW_SALE_FACTORY_OWNER = makeAddr("New saleFactory owner");
        // Address of the original sale factory owner
        address ORIGNIAL_SALE_FACTORY_OWNER = address(this);

        // Create a new sale
        uint256 _saleIndex = createNewSaleTransfer();

        // Set the sale price
        saleFactory.setPriceInUsd(_saleIndex, USD_PRICE_PER_TOKEN);

        // Transfer contract to a new owner
        saleFactory.transferOwnership(NEW_SALE_FACTORY_OWNER);

        // Get initial balance of new owher
        uint256 _initialUsdcBalanceNewOwner = mockUsdc.balanceOf(
            NEW_SALE_FACTORY_OWNER
        );

        // Get initial balance of sender (USDC owner address)
        uint256 initialUsdcBalanceSender = mockUsdc.balanceOf(USDC_OWNER);

        // Get the initial balance of the orignal onwer
        uint256 initialUsdcBalanceOriginalOwner = mockUsdc.balanceOf(
            ORIGNIAL_SALE_FACTORY_OWNER
        );

        // Approve and buy the amount the sale will cost
        vm.startPrank(USDC_OWNER);
        mockUsdc.approve(address(saleFactory), USD_ALLOWANCE);
        saleFactory.buyWithUsdc(_saleIndex, AMOUNT_TO_PURCHASE, REFERRAL_CODE);
        vm.stopPrank();

        // Make sure the new owner got the USDC balance
        assertEq(
            mockUsdc.balanceOf(NEW_SALE_FACTORY_OWNER),
            _initialUsdcBalanceNewOwner + USD_ALLOWANCE
        );

        // Make sure balance is gone from original sender (usdc sender)
        assertEq(
            mockUsdc.balanceOf(USDC_OWNER),
            initialUsdcBalanceSender - USD_ALLOWANCE
        );

        // Make sure the old owner didn't get anything (current balance - initial usdc)
        assertEq(
            mockUsdc.balanceOf(ORIGNIAL_SALE_FACTORY_OWNER),
            initialUsdcBalanceOriginalOwner
        );
    }
}

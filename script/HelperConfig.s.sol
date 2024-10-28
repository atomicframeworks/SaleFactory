// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

// The mocks
import {MockUsdt} from "../test/mocks/MockUsdt.sol";
import {MockUsdc} from "../test/mocks/MockUsdc.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8;
    // 2,132.68 price * 6 decimals (since it's 8 decimals total the 68 cents is part of the 8)
    int256 public constant INITIAL_PRICE = 213268e6;

    struct NetworkConfig {
        address usdcAddress;
        address usdtAddress;
        address priceFeedAddress;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            usdtAddress: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            // https://developers.circle.com/stablecoins/docs/usdc-on-main-networks
            usdcAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
            priceFeedAddress: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });

        return config;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            // Just setting to USDC address for both. They work basically the same and simpler to get faucet USDC and use for both
            usdtAddress: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            // https://developers.circle.com/stablecoins/docs/usdc-on-test-networks
            usdcAddress: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#sepolia-testnet
            priceFeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });

        return config;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Return active network config if not empty
        if (activeNetworkConfig.usdcAddress != address(0)) {
            return activeNetworkConfig;
        }

        // Some mock USDT/USDC addresses
        vm.startBroadcast();
        MockUsdt _mockUsdt = new MockUsdt();
        MockUsdc _mockUsdc = new MockUsdc();
        vm.stopBroadcast();

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

        NetworkConfig memory config = NetworkConfig({
            usdtAddress: address(_mockUsdt),
            usdcAddress: address(_mockUsdc),
            priceFeedAddress: address(mockPriceFeed)
        });

        return config;
    }
}

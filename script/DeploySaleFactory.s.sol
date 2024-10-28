// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SaleFactory} from "../src/SaleFactory.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySaleFactory is Script {
    // Get the current chain ID
    uint256 chainId = block.chainid;

    // The initial owner (either message sender or set up in setUp )
    address initialAuthority;

    function setUp() public {
        console.log("SET UP - Message Sender", msg.sender);
        // Check if deploying to Ethereum mainnet (chain ID 1)
        if (chainId == 1) {
            console.log("USING MAINNET CONFIG");
            // Use INITIAL_AUTHORITY from environment variables
            initialAuthority = vm.envAddress("INITIAL_AUTHORITY");
            console.log("Initial Authority:", initialAuthority);
        } else {
            // Use the deployer's address as the initial authority on non-mainnet networks
            initialAuthority = msg.sender;
        }
    }

    function run() public returns (SaleFactory) {
        (
            address _usdtAddress,
            address _usdcAddress,
            address _priceFeedAddress
        ) = new HelperConfig().activeNetworkConfig();

        vm.startBroadcast();
        SaleFactory saleFactory = new SaleFactory(
            initialAuthority,
            _usdcAddress,
            _usdtAddress,
            _priceFeedAddress
        );
        vm.stopBroadcast();
        return saleFactory;
    }
}

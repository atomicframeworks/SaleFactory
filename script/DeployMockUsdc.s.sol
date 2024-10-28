// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUsdc} from "../test/mocks/MockUsdc.sol";

contract DeployMockUsdc is Script {
    function setUp() public {}

    function run() public returns (MockUsdc) {
        vm.broadcast();
        MockUsdc mockUsdc = new MockUsdc();
        return mockUsdc;
    }
}

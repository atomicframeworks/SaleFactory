// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUsdt} from "../test/mocks/MockUsdt.sol";

contract DeployMockUsdt is Script {
    function setUp() public {}

    function run() public returns (MockUsdt) {
        vm.broadcast();
        MockUsdt mockUsdt = new MockUsdt();
        return mockUsdt;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockErc20} from "../test/mocks/MockErc20.sol";

contract DeployMockErc20 is Script {
    function setUp() public {}

    function run() public returns (MockErc20) {
        vm.broadcast();
        MockErc20 mockErc20 = new MockErc20();
        return mockErc20;
    }
}

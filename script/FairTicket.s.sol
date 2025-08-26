// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {FairTicket} from "../src/FairTicket.sol";

contract FairTicketScript is Script {
    FairTicket public fairTicket;

    function setUp() public {}

    function run() public {
        // vm.envUint会读取对应名称的环境变量，这里读取了PRIVATE_KEY和START_GLOBAL_ID
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 startGlobalId = vm.envUint("START_GLOBAL_ID");
        // 使用 deployerPrivateKey 进行广播交易 将FairTicket及其相关的合约进行上链
        vm.startBroadcast(deployerPrivateKey);
        fairTicket = new FairTicket(startGlobalId);
        vm.stopBroadcast();
    }
}

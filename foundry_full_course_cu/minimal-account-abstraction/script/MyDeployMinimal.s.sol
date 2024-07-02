// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 

import {Script} from "forge-std/Script.sol";
import {MyMinimalAccount} from "../src/ethereum/MyMinimalAccount.sol"; 
import {MyHelperConfig} from "./MyHelperConfig.s.sol"; 

contract MyDeployMinimal is Script {
  function run() public {

  } 

  function deployMyMinimalAccount() public {
    MyHelperConfig myHelperConfig = new MyHelperConfig();
    MyHelperConfig.NetworkConfig memory config = myHelperConfig.getConfig(); 

    vm.startBroadcast(); 
    MyMinimalAccount myMinimalAccount = new MyMinimalAccount(config.entryPoint); 
    myMinimalAccount.transferOwnership(msg.sender); 

    vm.stopBroadcast();
  }

  
  
}
// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 

import {Script, console2} from "@forge-std/Script.sol";
import {MyMinimalAccount} from "../src/ethereum/MyMinimalAccount.sol"; 
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";  

contract MyHelperConfig is Script {
  error HelperConfig__InvalidChainId(); 

  struct NetworkConfig {
    address entryPoint; 
    address account; 
  }

  uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111; 
  uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300; 
  uint256 constant LOCAL_CHAIN_ID = 31337; 
  address constant BURNER_WALLET = 0xaDffAe7FbDdfe26F5EB0959848df90dF79931387; 
  // address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38; 
  address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; 

  NetworkConfig public localNetworkConfig; 
  mapping(uint256 chainId => NetworkConfig) public networkConfig;

  constructor() { 
    networkConfig[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig(); 
  }

  function getConfig() public returns (NetworkConfig memory) { 
    return getConfigByChainId(block.chainid); 
  }

  function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) { 
    if (chainId == LOCAL_CHAIN_ID) { 
      return getOrCreateAnvilEthConfig(); 
    } else if (networkConfig[chainId].account != address(0)) {
      return networkConfig[chainId]; 
    } else {
      revert HelperConfig__InvalidChainId(); 
    }

  }

  function  getEthSepoliaConfig() public pure returns(NetworkConfig memory){ 
    return NetworkConfig({
      entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, 
      account: BURNER_WALLET
    });
  }

  function  getZkSyncSepoliaConfig() public pure returns(NetworkConfig memory){ 
    return NetworkConfig({
      entryPoint: address(0), 
      account: BURNER_WALLET
    });
  }

  function  getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){ 
    if (localNetworkConfig.account != address(0)) { 
      return localNetworkConfig; 
    }
    
    // deploy mock entrypoint contract.
    console2.log("Deploying My Mocks..."); 
    vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT); 
    EntryPoint entryPoint = new EntryPoint();  
    vm.stopBroadcast(); 

    localNetworkConfig =  NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT}); 
    return localNetworkConfig; 
  }
}
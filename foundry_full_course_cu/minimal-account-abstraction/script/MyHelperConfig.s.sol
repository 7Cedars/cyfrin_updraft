// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 

import {Script} from "forge-std/Script.sol";
import {MyMinimalAccount} from "../src/ethereum/MyMinimalAccount.sol"; 

contract MyHelperConfig is Script {
  error HelperConfig__InvalidChainId(); 

  struct NetworkConfig {
    address entryPoint; 
    address account; 
  }

  uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111; 
  uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300; 
  uint256 constant LOCAL_CHAIN_ID = 31337; 
  address constant BURNER_WALLET 

  NetworkConfig public localNetworkConfig; 
  mapping(uint256 chainId => NetworkConfig) public networkConfig; 

  constructor() { 
    networkConfig[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig(); 
  }

  function getConfig() public returns (NetworkConfig memory) { 
    return getConfigByChainid(block.chainId); 
  }

  function getConfigByChainid(uint256 chainId) public returns (NetworkConfig memory) { 
    if (chainId == LOCAL_CHAIN_ID) { 
      return getOrCreateAnvilEthConfig(); 
    } else if (networkConfig[chainId].entryPoint != address(0)) {
      return networkConfig[chainId]; 
    } else {
      revert HelperConfig__InvalidChainId(); 
    }

  }

  function  getEthSepoliaConfig() public pure returns(NetworkConfig memory){ 
    return NetworkConfig({
      entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
    });
  }

  function  getZkSyncSepoliaConfig() public pure returns(NetworkConfig memory){ 
    return NetworkConfig({
      entryPoint: address(0)
    });
  }

  function  getOrCreateAnvilEthConfig() public pure returns(NetworkConfig memory){ 
    if (localNetworkConfig.entryPoint != address(0)) { 
      return localNetworkConfig; 
    }
    
    // deploy mock entrypoint contract. 
  }


}
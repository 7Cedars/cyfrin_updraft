// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 

import {Script} from "@forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MyHelperConfig} from "script/MyHelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MySendPackedUserOp is Script {
  using MessageHashUtils for bytes32;

  function run() public {}

  function generateSignedUserOperation (
    bytes memory callData,
    MyHelperConfig.NetworkConfig memory config
    ) public view returns (PackedUserOperation memory) {
    uint256 nonce = vm.getNonce(config.account);
    PackedUserOperation memory userOp = _generateuserOperation(callData, config.account, nonce);

    // getUserOphash
    bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
    bytes32 digest = userOpHash.toEthSignedMessageHash();

    //sign it
    uint8 v;
    bytes32 r; 
    bytes32 s;
    uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; 
    if (block.chainid == 31337) {
      (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
    } else {
      (v, r, s) = vm.sign(config.account, digest);
    }
    userOp.signature = abi.encodePacked(r, s, v);
    return userOp;
  }

  function _generateuserOperation (
    bytes memory callData,
    address sender,
    uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
      uint256 verificationGasLimit = 16777216;
      uint256 callGasLimit = verificationGasLimit;
      uint256 maxPriorityFeePerGas = 256;
      uint256 maxFeePerGas = maxPriorityFeePerGas;

      return PackedUserOperation({
        sender: sender,
        nonce: nonce,
        initCode: hex"",
        callData:callData,
        accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
        preVerificationGas: verificationGasLimit,
        gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
        paymasterAndData: hex"",
        signature: hex""
    });
  }

// struct PackedUserOperation {
//     address sender;
//     uint256 nonce;
//     bytes initCode;
//     bytes callData;
//     bytes32 accountGasLimits;
//     uint256 preVerificationGas;
//     bytes32 gasFees;
//     bytes paymasterAndData;
//     bytes signature;
// }
} 


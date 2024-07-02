// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol"; 
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol"; 
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MyMinimalAccount is IAccount, Ownable {
  /////////////////////////////////////////////////////////////
  //                           ERRORS                        //
  /////////////////////////////////////////////////////////////
  error MyMinimalAccount_NotFromEntryPoint(); 
  error MyMinimalAccount_NotFromEntryPointOrOwner();
  error MinimalAccount_CallFailed(bytes);  

    
  /////////////////////////////////////////////////////////////
  //                       STATE VARIABLE                    //
  /////////////////////////////////////////////////////////////

  IEntryPoint private immutable i_entryPoint;


  /////////////////////////////////////////////////////////////
  //                          MODIFIERS                      //
  /////////////////////////////////////////////////////////////
  modifier requireFromEntryPoint() {
    if (msg.sender != address(i_entryPoint)) { 
      revert MyMinimalAccount_NotFromEntryPoint(); 
    }

    _; 
  }

  modifier requireFromEntryPointOrOwner() {
    if (msg.sender != address(i_entryPoint) &&  msg.sender != owner()) { 
      revert MyMinimalAccount_NotFromEntryPointOrOwner(); 
    }

    _; 
  }

  /////////////////////////////////////////////////////////////
  //                          FUNCTIONS                      //
  /////////////////////////////////////////////////////////////
  constructor(address entryPoint) Ownable(msg.sender) {
    i_entryPoint = IEntryPoint(entryPoint); 
  } 

  receive() external payable {} 
  
  /////////////////////////////////////////////////////////////
  //                     INTERNAL FUNCTION                   //
  /////////////////////////////////////////////////////////////


  /////////////////////////////////////////////////////////////
  //                     EXTERNAL FUNCTION                   //
  /////////////////////////////////////////////////////////////
  function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
    (bool success, bytes memory result) = dest.call{value: value}(functionData); 
    if (!success) {
      revert MinimalAccount_CallFailed(result);
    }
  } 


  // a signature is valid if it is the contract owner. 
  function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
  ) external requireFromEntryPoint returns (uint256 validationData) {

    uint256 validationData = _validateSignature(userOp, userOpHash); 
    // _validateNonce(); -- optional. 

    _payPrefund(missingAccountFunds); 
  }

  // EIP-191 version of the signed hash
  function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view  returns (uint256 validationData) {

    bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature); 
    if (signer != owner()) {
      return SIG_VALIDATION_FAILED;
    } else {
      return SIG_VALIDATION_SUCCESS;
    }
  }

  function _payPrefund(uint256 missingAccountFunds) internal {
    if (missingAccountFunds != 0) {
      (bool success ,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}(""); 
      (success); 
    } 
  }

  /////////////////////////////////////////////////////////////
  //                           GETTERS                       //
  /////////////////////////////////////////////////////////////
  function getEntryPoint() external view returns (address) { 
      return address(i_entryPoint); 
  }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
  IAccount, 
  ACCOUNT_VALIDATION_SUCCESS_MAGIC
  } from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
  Transaction, 
  MemoryTransactionHelper
  } from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
  NONCE_HOLDER_SYSTEM_CONTRACT, 
  BOOTLOADER_FORMAL_ADDRESS,
  DEPLOYER_SYSTEM_CONTRACT
  } from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; 
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";



// NB: need to add --system-mode=true at compile. 



contract MyZkMinimalAccount is IAccount, Ownable {
  using MemoryTransactionHelper for Transaction;  

  error MyZkMinimalAccount_NotEnoughBalance(); 
  error MyZkMinimalAccount_NotFromBootloader(); 
  error MyZkMinimalAccount_NotFromBootloaderOrOwner(); 
  error MyZkMinimalAccount_ValidationFailed();
  error MyZkMinimalAccount_ExecutionFailed();
  error  MyZkMinimalAccount_FailedToPay(); 

///////////////////////////////////////////////////////
//                      MODIFIERS                    //
///////////////////////////////////////////////////////
modifier requireFromBootLoader() {
  if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
    revert MyZkMinimalAccount_NotFromBootloader(); 
  }
  _; 
}

modifier requireFromBootLoaderOrOwner() {
  if(msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
    revert MyZkMinimalAccount_NotFromBootloaderOrOwner(); 
  }
  _; 
}


///////////////////////////////////////////////////////
//                        FUNCTIONS                  //
///////////////////////////////////////////////////////

  constructor() Ownable(msg.sender) {} 

  receive() external payable {}  

///////////////////////////////////////////////////////
//                  EXTERNAL FUNCTION                //
///////////////////////////////////////////////////////
  function validateTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
      external
      payable
      requireFromBootLoader
      returns (bytes4 magic)
    {
      return _validateTransaction(_transaction);
    }

  function executeTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
      external
      payable
      requireFromBootLoaderOrOwner
    {
      _executeTransaction(_transaction); 
    }

  // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
  // since it typically should not be trusted.
  function executeTransactionFromOutside(Transaction memory _transaction) 
      external 
      payable 
  {
    bytes4 magic = _validateTransaction(_transaction);
    if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
        revert MyZkMinimalAccount_ValidationFailed();
    }
    _executeTransaction(_transaction);  
  }

  function payForTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction)
      external
      payable
    {
      bool success = _transaction.payToTheBootloader(); 
      if(!success) { 
        revert MyZkMinimalAccount_FailedToPay(); 
      }
    }

  function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
      external
      payable
    {} 

  ///////////////////////////////////////////////////////
  //                  INTERNAL FUNCTION                //
  ///////////////////////////////////////////////////////

  function _validateTransaction (Transaction memory _transaction) internal returns (bytes4 magic) {
      // call nonceholder
      SystemContractsCaller.systemCallWithPropagatedRevert(
        uint32(gasleft()), 
        address(NONCE_HOLDER_SYSTEM_CONTRACT), 
        0, 
        abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

      // check for fee to pay. 
      uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
      if (totalRequiredBalance > address(this).balance) {
        revert MyZkMinimalAccount_NotEnoughBalance(); 
      }

      // check the signature. 
      bytes32 txhash = _transaction.encodeHash();
      // here left out a line. see https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/validate-tx?lesson_format=video
      address signer = ECDSA.recover(txhash, _transaction.signature); 
      bool isValidSigner = signer == owner();
      if (isValidSigner) {
        magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC; 
      } else {
        magic = bytes4(0); 
      }
      return magic; 
  }

  function _executeTransaction (Transaction memory _transaction) internal { 
     address to = address(uint160(_transaction.to)); 
     uint128 value = Utils.safeCastToU128(_transaction.value); 
      bytes memory data = _transaction.data; 

      if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
        uint32 gas = Utils.safeCastToU32(gasleft());
        SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
      } else {
        bool success;
        assembly {
          success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
        }
        if (!success){ 
          revert MyZkMinimalAccount_ExecutionFailed(); 
        }
      }
  }

}




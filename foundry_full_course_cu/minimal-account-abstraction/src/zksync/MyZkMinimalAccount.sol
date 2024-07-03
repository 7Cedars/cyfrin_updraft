// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

contract MyZkMinimalAccount is IAccount {
  function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
      external
      payable
      returns (bytes4 magic)
    {}

  function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
      external
      payable
    {}

  // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
  // since it typically should not be trusted.
  function executeTransactionFromOutside(Transaction memory _transaction) external payable;

  function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
      external
      payable
    {}

  function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
      external
      payable
    {} 
}




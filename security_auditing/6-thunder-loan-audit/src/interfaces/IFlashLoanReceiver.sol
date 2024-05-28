// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// £unused import 
// £audit-info? bad practice to change live code to imprve testing. Need to remove from {MockFlashLoanReceiver}
// £this import is only used in test file. 
import { IThunderLoan } from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
interface IFlashLoanReceiver {
    // @audit: where is the natspec? 
    // qs: what are all the patameters? 
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);
}

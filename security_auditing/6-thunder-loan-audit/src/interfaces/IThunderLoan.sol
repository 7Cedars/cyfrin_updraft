// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @audit-low Iaudit-low  IThunderLoan is not implemented but he thunderloan contract. 
// £audit-low/informational: input parameters differ from repay function in ThunderLoan: address => ERC20. 
// £q: why is this the case? 
interface IThunderLoan {
    function repay(address token, uint256 amount) external;
}


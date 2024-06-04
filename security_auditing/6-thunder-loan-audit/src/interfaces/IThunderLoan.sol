// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// £ written up  IThunderLoan is not implemented but he thunderloan contract. 
// £ written-up input parameters differ from repay function in ThunderLoan: address => ERC20. 
// £ q: why is this the case? -- just to make writing testing scripts easier I guess? 
interface IThunderLoan {
    function repay(address token, uint256 amount) external;
}


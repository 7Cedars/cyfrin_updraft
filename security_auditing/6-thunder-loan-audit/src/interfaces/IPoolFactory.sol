// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// £ explain: interface to work with poolFactory of TSwap
interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}

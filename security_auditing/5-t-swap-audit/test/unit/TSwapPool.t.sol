// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address liquidityProvider2 = makeAddr("liquidityProvider2");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 100e18);
        poolToken.mint(user, 100e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    function test_depositDeadlineIgnored() public {
        uint256 singleDeposit = 100e18; 
        uint64 deadline = uint64(block.timestamp);   

        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), singleDeposit);
        poolToken.approve(address(pool), singleDeposit);
        pool.deposit(singleDeposit, singleDeposit, singleDeposit, deadline);
        
        // We warp & pass the deadline. 
        vm.warp(block.timestamp + 1000); 
        weth.approve(address(pool), singleDeposit);
        poolToken.approve(address(pool), singleDeposit);
        // We deposit with the same deadline and this should revert, but does not. 
        pool.deposit(singleDeposit, singleDeposit, singleDeposit, deadline);
        vm.stopPrank();

        assertEq(pool.balanceOf(liquidityProvider), singleDeposit * 2);
        assertEq(weth.balanceOf(address(pool)), singleDeposit * 2);
        assertEq(poolToken.balanceOf(address(pool)), singleDeposit * 2);
    }

    function test_lackingSlippageProtection () public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        // meaning we should expect to pay ~11 in tokenA for ~9 in weth. 
        uint256 expectedPayment = 11e18;
        
        // The liquidity provider now comes around and does a big swap poolTokens -> wEth 
        uint256 minOutputAmount = 9e18; 
        vm.startPrank(liquidityProvider);
            poolToken.approve(address(pool), 100e18);
            pool.swapExactInput(
                poolToken, // = inputToken 
                25e18, // = inputAMount
                weth, // = outputToken 
                minOutputAmount, // = outputAmount
                uint64(block.timestamp)); // deadline
        vm.stopPrank();

        uint256 poolTokenBalanceuserBefore = poolToken.balanceOf(user); 
        
        vm.startPrank(user);
        poolToken.approve(address(pool), 100e18);
        pool.swapExactOutput(
            poolToken, // = inputToken 
            weth, // = outputToken 
            9e18, // = outputAmount 
            uint64(block.timestamp)); // deadline
        vm.stopPrank();

        uint256 poolTokenBalanceuserAfter = poolToken.balanceOf(user); 
        console.log("Difference between expected and actual payment: ", (poolTokenBalanceuserBefore - poolTokenBalanceuserAfter) - expectedPayment); 

        assert(poolTokenBalanceuserBefore - poolTokenBalanceuserAfter > expectedPayment);
    }

    function test_incorrectAmountsAtSellPoolTokens () public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 poolTokensToSell = 5e18; 

        uint256 poolTokenBalanceuserBefore = poolToken.balanceOf(user); 
        
        vm.startPrank(user);
        poolToken.approve(address(pool), 100e18);
        weth.approve(address(pool), 100e18);
        pool.sellPoolTokens(poolTokensToSell);
        vm.stopPrank();

        uint256 poolTokenBalanceuserAfter = poolToken.balanceOf(user); 

        assert(poolTokenBalanceuserBefore - poolTokenBalanceuserAfter != poolTokensToSell);
    }

    function testInvariantBroken() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64( block.timestamp));
        vm.stopPrank();

        uint256 outputWeth = 1e17;
        uint256 numberOfSwaps = 10; 
        int256 startingY = int256(weth.balanceOf(address(pool)));
        int256 expectedDeltaY = int256(-1) * int256(outputWeth);

        vm.startPrank(user);
        for (uint256 i; i < numberOfSwaps; i++) {
            poolToken.approve(address(pool), type(uint256).max);
            pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        }
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(pool));
        int256 actualDeltaY = int256(endingY) - int256(startingY);

        vm.assertEq(expectedDeltaY, actualDeltaY); 
    }


}

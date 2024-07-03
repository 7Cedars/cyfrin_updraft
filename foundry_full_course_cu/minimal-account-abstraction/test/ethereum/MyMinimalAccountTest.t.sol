// SPDX-License-Identifier: MIT
// Following along with class @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
pragma solidity 0.8.24; 


import {Test} from "forge-std/Test.sol";
import {MyMinimalAccount} from "src/ethereum/MyMinimalAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MyDeployMinimal} from "script/MyDeployMinimal.s.sol";
import {MyHelperConfig} from "script/MyHelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MySendPackedUserOp} from "script/MySendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";  

contract MyMinimalAccountTest is Test {
  using MessageHashUtils for bytes32;

  MyHelperConfig myHelperConfig;
  MyMinimalAccount myMinimalAccount;
  ERC20Mock usdc;
  MySendPackedUserOp sendPackedUserOp;

  uint256 constant AMOUNT = 222;
  address randomUser = makeAddr("randomUser");

  function setUp() public {
    MyDeployMinimal myDeployMinimal = new MyDeployMinimal();
    (myHelperConfig, myMinimalAccount) = myDeployMinimal.deployMyMinimalAccount();
    usdc = new ERC20Mock();
    sendPackedUserOp = new MySendPackedUserOp();
  }

  function testOwnerCanExecuteCommands() public {
    //arrange
    assertEq(usdc.balanceOf(address(myMinimalAccount)), 0);
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myMinimalAccount), AMOUNT);

    // act
    vm.prank(myMinimalAccount.owner());
    myMinimalAccount.execute(dest, value, functionData);

    // assert
    assertEq(usdc.balanceOf(address(myMinimalAccount)), AMOUNT);
  }

  function testNonOwnerCannotExecuteCommands() public {
    //arrange
    assertEq(usdc.balanceOf(address(myMinimalAccount)), 0);
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myMinimalAccount), AMOUNT);

    // act
    vm.prank(randomUser);
    vm.expectRevert(MyMinimalAccount.MyMinimalAccount_NotFromEntryPointOrOwner.selector);
    myMinimalAccount.execute(dest, value, functionData);
  }

  function testRecoverSignedOp2() public {
    // arrange
    assertEq(usdc.balanceOf(address(myMinimalAccount)), 0);
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myMinimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MyMinimalAccount.execute.selector, dest, value, functionData);
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, myHelperConfig.getConfig());
    bytes32 userOperationHash = IEntryPoint(myHelperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

    // act
    address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature); 
    
    // assert
    assertEq(actualSigner, myMinimalAccount.owner());
  }

  function testValidationUserOps2() public {
    // arrange
    assertEq(usdc.balanceOf(address(myMinimalAccount)), 0);
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myMinimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MyMinimalAccount.execute.selector, dest, value, functionData);
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, myHelperConfig.getConfig());
    bytes32 userOperationHash = IEntryPoint(myHelperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    uint256 missingAccountFunds = 1e18; 

    // act
    vm.prank(myHelperConfig.getConfig().entryPoint);
    uint256 validationData = myMinimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds); 
    
    // assert
    assertEq(validationData, 0);
  }

  function testEntryPointCanExecuteCommands2() public {
    // arrange
    assertEq(usdc.balanceOf(address(myMinimalAccount)), 0);
    address dest = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(myMinimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MyMinimalAccount.execute.selector, dest, value, functionData);
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, myHelperConfig.getConfig());
    // bytes32 userOperationHash = IEntryPoint(myHelperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    uint256 missingAccountFunds = 1e18; 

    vm.deal(address(myMinimalAccount), 1e18);
    PackedUserOperation[] memory ops = new PackedUserOperation[](1); 
    ops[0] = packedUserOp; 

    //act 
    vm.prank(randomUser); 
    IEntryPoint(myHelperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser)); 

    //assert 
    assertEq(usdc.balanceOf(address(myMinimalAccount)), AMOUNT);
  }
}
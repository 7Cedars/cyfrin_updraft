// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MondrianWallet2} from "src/MondrianWallet2.sol";

// Era Imports
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// OZ Imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Foundry Devops
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

// interface _CheatCodes {
//     function ffi(string[] calldata) external returns (bytes memory);
// }

contract MondrianWallet2Test is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32;
    MondrianWallet2 implementation;
    MondrianWallet2 mondrianWallet;
    ERC20Mock usdc;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;
    // _CheatCodes cheatCodes = _CheatCodes(VM_ADDRESS);

    uint256 constant AMOUNT = type(uint256).max;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        implementation = new MondrianWallet2();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        mondrianWallet = MondrianWallet2(address(proxy));
        mondrianWallet.initialize();
        mondrianWallet.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        // £NB: when writing up some of the security risks I HAVE TO NOT TO TAKE OUT THE FOLLOWING SENTENCE. 
        // vm.deal(address(mondrianWallet), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        vm.deal(address(mondrianWallet), AMOUNT);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);

        // Act
        vm.prank(mondrianWallet.owner());
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(mondrianWallet)), AMOUNT);
    }

    // You'll also need --system-mode=true to run this test
    function testZkValidateTransaction() public onlyZkSync {
        // Arrange
        vm.deal(address(mondrianWallet), AMOUNT);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction =
            _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    function testZkUpgradeContract() public onlyZkSync { // seems to work fine. 
        // Arrange
        vm.deal(address(mondrianWallet), AMOUNT);
        MondrianUpgraded upgradedImplementation;
        upgradedImplementation = new MondrianUpgraded();
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData; 
        
        // Validate transaction 1... 
        functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction1 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction1 = _signTransaction(transaction1);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic1 = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction1);

        
        mondrianWallet.upgradeToAndCall(address(upgradedImplementation), "");

        // Validate transaction 2, which is _exactly_ the same as transaction 1, but in upgraded wallet. 
        functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction2 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction2 = _signTransaction(transaction2);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic2 = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction2);

        // Assert
        assertEq(magic1, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
        assertEq(magic2, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
        assert(transaction1.nonce != transaction2.nonce);
    }

    // You'll also need --system-mode=true to run this test
    function testMissingReceiveBreaksContract() public onlyZkSync {
        // setting up accounts
        uint256 AMOUNT_TO_SEND = type(uint128).max;
        address THIRD_PARTY_ACCOUNT = makeAddr("3rdParty");
        vm.deal(THIRD_PARTY_ACCOUNT, AMOUNT);
        // Check if mondrianWallet indeed has no balance. 
        assertEq(address(mondrianWallet).balance, 0);  
        
        // creating transaction  
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);

        // Act & assert 
        // sending money directly to contract fails; it leaves contract with balance of 0. 
        vm.prank(mondrianWallet.owner());
        (bool success, ) = address(mondrianWallet).call{value: AMOUNT_TO_SEND}("");
        assertEq(success, false);
        assertEq(address(mondrianWallet).balance, 0);

        // as a result, validating transaction by bootloader fails
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        vm.expectRevert();
        mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // the same goes for executeTransactionFromOutside 
        vm.prank(THIRD_PARTY_ACCOUNT);
        vm.expectRevert();
        mondrianWallet.executeTransactionFromOutside(transaction);

        // also when eth is send with the transaction. 
        vm.prank(THIRD_PARTY_ACCOUNT);
        vm.expectRevert();
        mondrianWallet.executeTransactionFromOutside{value: AMOUNT_TO_SEND}(transaction);

        // Side note: it _is_ possible to execute function calls by owner through execute Transaction. But this defeats the purpose of Account Abstraction.
        // because there is no payMaster account, transactions NEED to be paid by contract. 
        vm.prank(mondrianWallet.owner());
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assertEq(usdc.balanceOf(address(mondrianWallet)), AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(mondrianWallet));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, // type 113 (0x71).
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }

    // function testPwned() public {
    //     string[] memory cmds = new string[](2);
    //     cmds[0] = "touch";
    //     cmds[1] = string.concat("youve-been-pwned");
    //     cheatCodes.ffi(cmds);
    // }
}

contract MondrianUpgraded is MondrianWallet2 {
    function dummyFunc(Transaction memory _transaction) external view returns (uint256 nonce) {
        return _transaction.nonce; 
    } 
}

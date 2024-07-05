// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// imports seem ok overall. 
// zkSync Era Imports
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC // seems ok. 
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
// checked installed version and it is exactly the same as the one installed in example from cyfrin updraft module. Ok.   
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT, // £question is this the correct address? seems ok. 
    BOOTLOADER_FORMAL_ADDRESS, // £question is this the correct address? Seem ok. 
    DEPLOYER_SYSTEM_CONTRACT // £question I think this is the correct address. Seems ok
    // NB! £audit-high the Constants contract has multiple contracts related to upgrades. They are not called.   
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

// OZ Imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol"; // £question. This one is not used. Why not?! -- is also not used in example from course. Maybe not an issue?
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MondrianWallet2
 * @notice Its upgradable! So there shouldn't be any issues because we can just upgrade!... right?
 */
contract MondrianWallet2 is IAccount, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using MemoryTransactionHelper for Transaction;

    error MondrianWallet2__NotEnoughBalance();
    error MondrianWallet2__NotFromBootLoader();
    error MondrianWallet2__ExecutionFailed();
    error MondrianWallet2__NotFromBootLoaderOrOwner();
    error MondrianWallet2__FailedToPay();
    error MondrianWallet2__InvalidSignature(); // £checked. Indeed an issue. See below: function executeTransactionFromOutside. This one is not used because signature not being checked. 

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // this modifier seems ok.  
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert MondrianWallet2__NotFromBootLoader();
        }
        _;
    }

    // this modifier seems ok.  
    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert MondrianWallet2__NotFromBootLoaderOrOwner();
        }
        _;
    }

    // £question: How do you setup an upgradable contract in zksync. Check. But 100% not like this.  
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // £question: See also above at function initialize(). How do you setup an upgradable contract in zksync? Check.  
    constructor() {
        _disableInitializers();
    }

    // £audit-medium/high: receive() external payable {} is MISSING. I checked. it is INDEED missing. Also Fallback is missing. 
    // -- if a transaction with eth is send, it will revert. When can / will this happen? 
    // see quick explanation here: https://ethereum.stackexchange.com/questions/125337/why-contract-must-have-a-receive-fallback-to-receive-ether-isnt-a-payable
    // -- check Eth flow in accoutn abstraction on zkSync... 

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice must increase the nonce
     * @notice must validate the transaction (check the owner signed the transaction)
     * @notice also check to see if we have enough money in our account
     */
    // This function seems ok. but need to check actual functionality in _validateTransaction below. 
    function validateTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
        return _validateTransaction(_transaction);
    }

    // This function seems ok. but need to check actual functionality in _executeTransaction below. 
    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    // £audit-high. The check is missing here. See also the error MondrianWallet2__InvalidSignature() that is not being used above.   
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        _validateTransaction(_transaction);
        _executeTransaction(_transaction);
    }

    // this seems ok... 
    // £question: check .payToTheBootloader? => seems ok. Same version as cyfrin updraft. (also: not in scope..)
    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert MondrianWallet2__FailedToPay();
        }
    }

    /**
     * @dev We never call this function, since we are not using a paymaster
     */
     // seems ok. 
    function prepareForPaymaster(
        bytes32, /*_txHash*/
        bytes32, /*_possibleSignedHash*/
        Transaction memory /*_transaction*/
    ) external payable {}

    // CONTINUE HERE // 
    // THERE ARE INDEED A NUMBER OF ISSUES IN THESE INTERNAL FUNCTIONS // 

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Apart from question below, this function seems to be fine.   
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) { // NB! the address needs to have balance! Without a receive function this will not be possible. Right? A payable function will just return money that is not necessary? 
        // £question: check if we can get funds into the contract as needed to execute functions. If not possible, this contract will not work. 
            revert MondrianWallet2__NotEnoughBalance();
        }

        // Check the signature
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            // £audit: this needs to be assembly. data field will not work. See cyfrin updraft course. 
            bool success;
            (success,) = to.call{value: value}(data);
            if (!success) {
                revert MondrianWallet2__ExecutionFailed();
            }
        }
    }

    // £audit: this won't work.. right? Needed for UUPS
    // this is not used anywhere. Probably for inhereted function. 
    // £question: as this function is called __authorizeUpgrade_ and it is left blank... does this mean ANYONE can upgrade?!   
    function _authorizeUpgrade(address newImplementation) internal override {}
}

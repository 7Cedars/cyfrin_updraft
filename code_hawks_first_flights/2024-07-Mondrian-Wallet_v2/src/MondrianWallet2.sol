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

    // £answered: How do you setup an upgradable contract in zksync. Check. But 100% not like this -- It seems very much like you can do it in this way :/   
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // £answered: See also above at function initialize(). How do you setup an upgradable contract in zksync? Check.  
    // £audit-low? Constructor unnecessary. 
    // from: https://docs.zksync.io/build/developer-reference/era-contracts/system-contracts
    /**
     * On ZKsync, there is no separation between deployed code and constructor code. The constructor is always a part of the deployment code of the contract. 
     * In order to protect it from being called, the compiler-generated contracts invoke constructor only if the isConstructor flag provided (it is only available for the system contracts).
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    // in zk-sync example this bit is left out. It is not needed. Is it a risk that it is included?? // It is at least inefficient & unneccessary... 
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
    // £answered: check .payToTheBootloader? => seems ok. Same version as cyfrin updraft. (also: not in scope..)
    // £answered, more or less. Does this function need access control?  It might need to, have to try:  
    // Interesting in example from ZKS~ync themselves (see https://github.com/code-423n4/2023-03-zksync//blob/main/contracts/DefaultAccount.sol) 
    // they DO have access control. This function can ONLY be called by bootloader (or mroe precisely, it returns empty data if not called by bootloader). 
    // £audit-low? What happens if another account pays? Can this block transactions?  
    // NB: Note that of these functions need to be paid directly, it breaks intended purpose of account abstraction.
    // NB2: This function is supposed to be called by bootloader, implying that funds need to be present in contract.  
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
     // seems ok - 
     // £answered: Can I get funds into contract via this function? NOPE. 
    function prepareForPaymaster(
        bytes32, /*_txHash*/
        bytes32, /*_possibleSignedHash*/
        Transaction memory /*_transaction*/
    ) external payable {}


    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Apart from question below, this function seems to be fine.   
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // £note: increases nonce. Seems correct. 
        // £answered: what happens with the nonce when the contract is upgraded? - Nonce just keeps on going coreectly 
        // Does it screw up uniqueness of nonces? (if they are reset on umpgrading impemantation, but proxy address remains the same?)
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) { // NB! the address needs to have balance! Without a receive function this will not be possible. Right? A payable function will just return money that is not necessary? 
        // £answered: check if we can get funds into the contract as needed to execute functions. If not possible, this contract will not work. = NOPE.  
            revert MondrianWallet2__NotEnoughBalance();
        }

        // Check the signature
        // £audit? Only the _owner_  can make transactions. Ok? I checked. And it is ok. 
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner(); // signature NEEDS to be owner! -- not any other user. Is this in line with intended functionality? 
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
            // check docs from zkSync. .call does not work.  
            bool success;
            // assembly {
            //     success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            // }
            (success,) = to.call{value: value}(data);
            if (!success) {
                revert MondrianWallet2__ExecutionFailed();
            }
        }
    }

    // £audit: this won't work.. right? Needed for UUPS
    // this is not used anywhere. Probably for inhereted function. 
    // £answered: as this function is called __authorizeUpgrade_ and it is left blank... does this mean ANYONE can upgrade?! YES. 
    // See UUPSUpgradable.sol. INDEED NEEDS ACCESS CONTROL. 
    function _authorizeUpgrade(address newImplementation) internal override {}
}

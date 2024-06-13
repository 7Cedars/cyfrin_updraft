// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/utils/Address.sol";
import {ChoosingRam} from "./ChoosingRam.sol";
import {RamNFT} from "./RamNFT.sol";

contract Dussehra {
    // checked: this means this is a payable address, but I do not see a receive or fallback function. 
    // what happens if you just send money here? -- it DOES have a sendValue function. -- THIS IS AN INTERNAL FUNCTION! CANNOT BE CALLED EXTERNALLY. 
    // BUT: what are functions from Address packacge not used?! -- include in remedees?  
    // £false-positive: the contract DOES have a fallback function! From where?! Old: ANY Ether send to this contract directly, will be stuck. There is NO way to retrieve it!  So if someone accidentally sends entry fee directly. too bad. 
    using Address for address payable; 

    // audit-info: no (indexed) return values what so ever in any of these error messages. Include.  
    error Dussehra__NotEqualToEntranceFee();
    error Dussehra__AlreadyPresent();
    error Dussehra__MahuratIsNotStart();
    error Dussehra__MahuratIsFinished();
    error Dussehra__AlreadyClaimedAmount();

    
    address[] public WantToBeLikeRam; // £skip / low? doubles with peopleLikeRam below, can be taken out. - not if this is turned into a counter.   
    uint256 public entranceFee; // £logged info: should be immutable. 
    address public organiser; // £logged info: should be immutable. 
    address public SelectedRam; 
    RamNFT public ramNFT;
    bool public IsRavanKilled; // £checked: better to set to internal? - no: a getter function is not a bad thing in this case.   
    mapping (address competitor => bool isPresent) public peopleLikeRam; //  £skip see above, doubles with WantToBeLikeRam
    
    uint256 public totalAmountGivenToRam; // £skip: better to set to internal or private? (no getter function, saves gas?) 
    ChoosingRam public choosingRamContract; // £skip: better to set to private? 

    // £skip add indexed? 
    // checked: how many additional events should be added? 
    event PeopleWhoLikeRamIsEntered(address competitor);

    modifier RamIsSelected() {
        require(choosingRamContract.isRamSelected(), "Ram is not selected yet!");
        _;
    }

    // £logged This modifier is only used once, integrate into function. 
    modifier OnlyRam() {
        require(choosingRamContract.selectedRam() == msg.sender, "Only Ram can call this function!");
        _;
    }

    // £logged This modifier is only used once, integrate into function. 
    modifier RavanKilled() {
        require(IsRavanKilled, "Ravan is not killed yet!");
        _;
    }

    constructor(uint256 _entranceFee, address _choosingRamContract, address _ramNFT) {
        entranceFee = _entranceFee;
        // £notice: BOTH dussehra AND RamNFT have a 'organiser' state variable. What happens if these are not the same? 
        // checked: or more precise: what are the priviledges of these two 'organiser's? How can/do they interfere with each other?
        // I think the trick is that it allows for resetting of address linked to NFTs. see RamNFT.   
        organiser = msg.sender; 
        // £notice: no zero check, no interface check. Any kind of RamNFT contract can be added here. 
        // £logged: needs to emit event
        ramNFT = RamNFT(_ramNFT);
    
        // £checked: this CALLS A FUNCTION [no it does NOT]! to set the choosingRamContract. should set directly as is done with ramNFT. 
        // £notice: no zero check, no interface check. Any kind of RamNFT contract can be added here. 
        // £note: this combines with notes I have at the function `ChoosingRam`. 
        // £logged: needs to emit event
        choosingRamContract = ChoosingRam(_choosingRamContract);
        
    }

    // £notes this function manages people's entree into the protocol. 
    // £note: they have to pay an entree fee
    // £note: address can only enter once.   
    // £skipped slither: Boolean constants can be used directly and do not need to be compare to true or false - there is a reason why this is done like this.
    function enterPeopleWhoLikeRam() public payable {
        // £skip. nope: now people have to enter with exact fee. Would possibly be better to say smaller than? 
        // £checked watch out: is somewhere the value entranceFee * people used? This DOES have to be in report. 
        // £checked what would happen if people send ether straight into contract? => eth is stuck. 
        if (msg.value != entranceFee) {
            revert Dussehra__NotEqualToEntranceFee();
        }

        // £logged info: literal boolean comparison unneccesary. 
        if (peopleLikeRam[msg.sender] == true){
            revert Dussehra__AlreadyPresent();
        }
        
        peopleLikeRam[msg.sender] = true;
        // £logged: why not use a simple counter? pushing to a list and then reading length of list = super gas inefficient. 
        WantToBeLikeRam.push(msg.sender);
        ramNFT.mintRamNFT(msg.sender);
        // £skip: possible CEI issue? -- emit should be before mintRamNFT? - slither picked this up. 
        // it does not seem to have any major impact. 
        emit PeopleWhoLikeRamIsEntered(msg.sender);
    }

    // £checked: can anyone call this function?! YEP - but that is not the main issue. 
    // also people who have absolutely nothing to do with the protocol?!  
    // £slither picked up on low-level call. 
    // £report-written the function is NOT checked on RavanisKilled. It can keep on being called.
    // £report-written: this function can be called multiple times. It only needs to be called twice (before withdraw function is called) to have all funds end up with organiser = rug pull! 
    function killRavana() public RamIsSelected {
        // £answer: how timestamp is set differs between chains, layout / decimals does not differ. I think.  
            // on zkSync Era the operator controls the frequency of L2 blocks and, hence, can manipulate the block timestamp and block number
            // on arbitrum ALSO different way, much more lenient. sequencer CAN adjust time.blockstamp. 
            // £logged and ehm BNB is being sunset! :D https://www.bnbchain.org/en/bnb-chain-fusion
        //  
        // £checked: timestamp can be altered on L1, but especially on L2! But how / to what extent? Need to find out..  
        if (block.timestamp < 1728691069) {
            revert Dussehra__MahuratIsNotStart();
        }
        if (block.timestamp > 1728777669) {
            revert Dussehra__MahuratIsFinished();
        }
        // £cheched: they do matter in selecting ram. Characteristic of ramNFT do not matter at all. When this function is called, ravan is killed. period. 
        // £this comes close to a scam? 
        // £logged: needs to emit event 
        IsRavanKilled = true;   
        // £logged: rounding error problem. if something does not divide by 2. What will happen?
        uint256 totalAmountByThePeople = WantToBeLikeRam.length * entranceFee;
        totalAmountGivenToRam = (totalAmountByThePeople * 50) / 100;
        // £note this is a low level call. should use sendValue.
        // £ANYONE can call this function. And it has a low level call to send eth to 'organiser'... AND does not follow CEI. 
        // £report-logged if organiser is a contract without receive / payable or anything - this will fail. 
        // -- pull over push. Better to have organiser pull the money - instead of pushing it. 
        // NOTE: if organiser is a contract that is not payable - the protocol is 100% bricked. because this call will always fail, 
        // ravana will not be killed, stopping everything else. 
        (bool success, ) = organiser.call{value: totalAmountGivenToRam}("");
        // £report-logged Reentrancy attack by organiser. - Really easy to pull off: by calling killRavana again when receiving money. 
        // in the withdraw function ot the case: it already empties amount on first go. 
        require(success, "Failed to send money to organiser");
    }

    // £skipped slither: Dussehra.killRavana() (src/Dussehra.sol#76-93) sends eth to arbitrary user -- in combo with remark above? 
    // £skipped slither: reentrancy vulnerability: there is no risk because no fund left.   
    // £slither picked up on low-level call. 
    function withdraw() public RamIsSelected OnlyRam RavanKilled {
        if (totalAmountGivenToRam == 0) {
            revert Dussehra__AlreadyClaimedAmount();
        }
        // £logged: rounding error problem. if something does not divide by 2. What will happen?! 
        // £should be balance account - then it will work.    
        uint256 amount = totalAmountGivenToRam;
        // £skip there is a check on who msg.sender is. But would be much clearer (and safer) to just use address selectedRam = choosingRamContract.selectedRam() 
        // AND use send value. The contract has this function from the imported Address package!
        // ALSO: this allows for reentrancy. ... but no way to really abuse this. right? (all eth has already been taken..)  
        // £logged: needs to emit event
        (bool success, ) = msg.sender.call{value: amount}("");

        require(success, "Failed to send money to Ram");
        // £logged: if not full amount was sent, it will get stuck in the contract. 
        totalAmountGivenToRam = 0;
    }
}

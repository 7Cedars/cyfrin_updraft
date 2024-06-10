// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/utils/Address.sol";
import {ChoosingRam} from "./ChoosingRam.sol";
import {RamNFT} from "./RamNFT.sol";

contract Dussehra {
    // £question: this means this is a payable address, but I do not see a receive or fallback function. 
    // what happens if you just send money here? -- it DOES have a sendValue function. -- THIS IS AN INTERNAL FUNCTION! CANNOT BE CALLED EXTERNALLY. 
    // BUT: what are functions from Address packacge not used?! -- include in remedees?  
    // £audit-high: ANY Ether send to this contract directly, will be stuck. There is NO way to retrieve it!  So if someone accidentally sends entry fee directly. too bad. 
    using Address for address payable; 

    // audit-info: no (indexed) return values what so ever in any of these error messages. Include.  
    error Dussehra__NotEqualToEntranceFee();
    error Dussehra__AlreadyPresent();
    error Dussehra__MahuratIsNotStart();
    error Dussehra__MahuratIsFinished();
    error Dussehra__AlreadyClaimedAmount();

    
    address[] public WantToBeLikeRam; // £audit-gas / low? doubles with peopleLikeRam below, can be taken out.  
    uint256 public entranceFee; // £audit info: should be immutable. 
    address public organiser; // £audit info: should be immutable. 
    address public SelectedRam; // fine I think... 
    RamNFT public ramNFT;
    bool public IsRavanKilled; // £q: better to set to private? 
    mapping (address competitor => bool isPresent) public peopleLikeRam; // see above, doubles with WantToBeLikeRam
    
    uint256 public totalAmountGivenToRam; // £q: better to set to internal or private? (no getter function, saves gas?) 
    ChoosingRam public choosingRamContract; // £q: better to set to private? 

    // £question add indexed? 
    // £question: how many additional events should be added? 
    event PeopleWhoLikeRamIsEntered(address competitor);

    modifier RamIsSelected() {
        require(choosingRamContract.isRamSelected(), "Ram is not selected yet!");
        _;
    }

    // £audit-gas This modifier is only used once, integrate into function. 
    modifier OnlyRam() {
        require(choosingRamContract.selectedRam() == msg.sender, "Only Ram can call this function!");
        _;
    }

    // £audit-gas This modifier is only used once, integrate into function. 
    modifier RavanKilled() {
        require(IsRavanKilled, "Ravan is not killed yet!");
        _;
    }

    constructor(uint256 _entranceFee, address _choosingRamContract, address _ramNFT) {
        entranceFee = _entranceFee;
        // £notice: BOTH dussehra AND RamNFT have a 'organiser' state variable. What happens if these are not the same? 
        // £question: or more precise: what are the priviledges of these two 'organiser's? How can/do they interfere with each other?  
        organiser = msg.sender; 
        // £notice: no zero check, no interface check. Any kind of RamNFT contract can be added here. 
        ramNFT = RamNFT(_ramNFT);
        // £audit-high: this CALLS A FUNCTION to set the choosingRamContract. should set directly as is done with ramNFT. 
        // £note: this combines with notes I have at the function `ChoosingRam`. 
        choosingRamContract = ChoosingRam(_choosingRamContract);
    }

    // £notes this function manages people's entree into the protocol. 
    // £note: they have to pay an entree fee
    // £note: address can only enter once.   
    // £audit-info slither: Boolean constants can be used directly and do not need to be compare to true or false.
    function enterPeopleWhoLikeRam() public payable {
        // £audit-low / info: now people have to enter with exact fee. Would possibly be better to say smaller than? 
        // £note watch out: is somewhere the value entranceFee * people used? This DOES have to be in report. 
        // £what would happen if people send ether straight into contract? 
        if (msg.value != entranceFee) {
            revert Dussehra__NotEqualToEntranceFee();
        }

        // £audit info: literal boolean comparison unneccesary. 
        if (peopleLikeRam[msg.sender] == true){
            revert Dussehra__AlreadyPresent();
        }
        
        peopleLikeRam[msg.sender] = true;
        // £audit-gas: why not use a simple counter? pushing to a list and then reading length of list = super gas inefficient. 
        WantToBeLikeRam.push(msg.sender);
        ramNFT.mintRamNFT(msg.sender);
        // £question: possible CEI issue? -- emit should be before mintRamNFT? - slither picked this up. 
        emit PeopleWhoLikeRamIsEntered(msg.sender);
    }

    // £q: can anyone call this function?! 
    // also people who have absolutely nothing to do with the protocol?!  
    // £slither picked up on low-level call. 
    // audit-high: this function can be called mutlile times. It only needs to be called twice (before withdraw function is called) to have all funds end up with organiser = rug pull! 
    function killRavana() public RamIsSelected {
        // £question: timestamp differs per chain? - would not be surprised if this is the case. 
        // £question: also: timestamp can be altered. But how / to what extent? Need to find out..  
        if (block.timestamp < 1728691069) {
            revert Dussehra__MahuratIsNotStart();
        }
        if (block.timestamp > 1728777669) {
            revert Dussehra__MahuratIsFinished();
        }
        // £audit-info Characteristic of ramNFT do not matter at all. When this function is called, ravan is killed. period. 
        // £this comes close to a scam? 
        // £note the function is NOT checked on RavanisKilled. It can keep on being called. 
        IsRavanKilled = true;
        // £note this smells. bad. 
        // £question YEP: what happens if people send ether straight into contract?! This next line will not be correct. 
        // it should use balance!   
        // £audit high?: rounding error problem. if something does not divide by 2. What will happen?! - see also note below.  
        uint256 totalAmountByThePeople = WantToBeLikeRam.length * entranceFee;
        totalAmountGivenToRam = (totalAmountByThePeople * 50) / 100;
        // £note this is a low level call. should use sendValue.
        // £ANYONE can call this function. And it has a low level call to send eth to 'organiser'... AND does not follow CEI. 
        (bool success, ) = organiser.call{value: totalAmountGivenToRam}("");
        require(success, "Failed to send money to organiser");
    }

    // £audit-high slither: Dussehra.killRavana() (src/Dussehra.sol#76-93) sends eth to arbitrary user -- in combo with remark above? 
    // £audit-high slither: reentrancy vulnerability.  
    // £slither picked up on low-level call. 
    function withdraw() public RamIsSelected OnlyRam RavanKilled {
        if (totalAmountGivenToRam == 0) {
            revert Dussehra__AlreadyClaimedAmount();
        }
        // £audit: rounding error problem. if something does not divide by 2. What will happen?! 
        // £should be balance account - then it will work.    
        uint256 amount = totalAmountGivenToRam;
        // £audit-low there is a check on who msg.sender is. But would be much clearer (and safer) to just use address selectedRam = choosingRamContract.selectedRam() 
        // AND use send value. The contract has this function from the imported Address package!
        // ALSO: this allows for reentrancy. ... but no way to really abuse this. right? (all eth has already been taken..)  
        (bool success, ) = msg.sender.call{value: amount}("");

        require(success, "Failed to send money to Ram");
        totalAmountGivenToRam = 0;
    }
}

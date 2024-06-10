// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Address} from "@openzeppelin/utils/Address.sol";
import {ChoosingRam} from "./ChoosingRam.sol";
import {RamNFT} from "./RamNFT.sol";

contract Dussehra {
    using Address for address payable;

    error Dussehra__NotEqualToEntranceFee();
    error Dussehra__AlreadyPresent();
    error Dussehra__MahuratIsNotStart();
    error Dussehra__MahuratIsFinished();
    error Dussehra__AlreadyClaimedAmount();

    address[] public WantToBeLikeRam;
    uint256 public entranceFee; // £audit info: should be immutable. 
    address public organiser; // £audit info: should be immutable. 
    address public SelectedRam;
    RamNFT public ramNFT;
    bool public IsRavanKilled;
    mapping (address competitor => bool isPresent) public peopleLikeRam;
    uint256 public totalAmountGivenToRam;
    ChoosingRam public choosingRamContract;


    event PeopleWhoLikeRamIsEntered(address competitor);

    modifier RamIsSelected() {
        require(choosingRamContract.isRamSelected(), "Ram is not selected yet!");
        _;
    }

    // £question wait what does this do? Who / what is selected ram?  
    modifier OnlyRam() {
        require(choosingRamContract.selectedRam() == msg.sender, "Only Ram can call this function!");
        _;
    }

    modifier RavanKilled() {
        require(IsRavanKilled, "Ravan is not killed yet!");
        _;
    }

    constructor(uint256 _entranceFee, address _choosingRamContract, address _ramNFT) {
        entranceFee = _entranceFee;
        organiser = msg.sender;
        ramNFT = RamNFT(_ramNFT);
        choosingRamContract = ChoosingRam(_choosingRamContract);
    }

    
    function enterPeopleWhoLikeRam() public payable {
        // £audit-low: now people have to enter with exact fee. Would possibly be better to say smaller than? 
        if (msg.value != entranceFee) {
            revert Dussehra__NotEqualToEntranceFee();
        }

        if (peopleLikeRam[msg.sender] == true){
            revert Dussehra__AlreadyPresent();
        }
        
        peopleLikeRam[msg.sender] = true;
        // £audit-gas: why not use a simple counter? pushing to a list and then reading length of list = super gas inefficient. 
        WantToBeLikeRam.push(msg.sender);
        ramNFT.mintRamNFT(msg.sender);
        // £question: possible CEI issue? -- emit should be before mintRamNFT? 
        emit PeopleWhoLikeRamIsEntered(msg.sender);
    }

    // £q: can anyone call this function?! 
    // also people who have absolutely nothing to do with the protocol?!  
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
        IsRavanKilled = true;
        // £note this smells. bad. 
        uint256 totalAmountByThePeople = WantToBeLikeRam.length * entranceFee;
        totalAmountGivenToRam = (totalAmountByThePeople * 50) / 100;
        (bool success, ) = organiser.call{value: totalAmountGivenToRam}("");
        require(success, "Failed to send money to organiser");
    }

    // £audit access priviledge mix up? OnlyRam allows anyone whith 
    function withdraw() public RamIsSelected OnlyRam RavanKilled {
        if (totalAmountGivenToRam == 0) {
            revert Dussehra__AlreadyClaimedAmount();
        }
        uint256 amount = totalAmountGivenToRam;
        (bool success, ) = msg.sender.call{value: amount}("");

        require(success, "Failed to send money to Ram");
        totalAmountGivenToRam = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RamNFT} from "./RamNFT.sol";

contract ChoosingRam {
    // £checked: how many events need to be added? 
    // £skipped: include (indexed) vars in errors and events.   
    error ChoosingRam__InvalidTokenIdOfChallenger();
    error ChoosingRam__InvalidTokenIdOfPerticipent();
    error ChoosingRam__TimeToBeLikeRamFinish();
    error ChoosingRam__CallerIsNotChallenger();
    error ChoosingRam__TimeToBeLikeRamIsNotFinish();
    error ChoosingRam__EventIsFinished();

    bool public isRamSelected; // needs to be public 
    RamNFT public ramNFT; // can be internal? 

    address public selectedRam; // needs to be public 

    // £report-written: this require can be revised to if statement with function return = more gas efficient.  
    modifier RamIsNotSelected() {
        require(!isRamSelected, "Ram is selected!");
        _;
    }

    // £report-written: modifier only used once. Integrate into function. 
    modifier OnlyOrganiser() {
        require(ramNFT.organiser() == msg.sender, "Only organiser can call this function!"); 
        _;
    }

    constructor(address _ramNFT) {
        // £report-written - no need to initialise state vars to false.  
        isRamSelected = false; 
        // £report-written-low? No address(0) check.. or ANYTHING else - NOT true. it loads as RamNFT.. 
        ramNFT = RamNFT(_ramNFT); 
    }
      
    // £notice: this function raises value of either tokenIdOfChallenger OR tokenIdOfAnyPerticipent.
    // £logged: this functionality of the contract does not have any influence over broader protocol. It is useless. 
    // 
    function increaseValuesOfParticipants(uint256 tokenIdOfChallenger, uint256 tokenIdOfAnyPerticipent)
        public
        RamIsNotSelected
    {
        if (tokenIdOfChallenger > ramNFT.tokenCounter()) {
            revert ChoosingRam__InvalidTokenIdOfChallenger();
        }
        if (tokenIdOfAnyPerticipent > ramNFT.tokenCounter()) {
            revert ChoosingRam__InvalidTokenIdOfPerticipent();
        }
        if (ramNFT.getCharacteristics(tokenIdOfChallenger).ram != msg.sender) {
            revert ChoosingRam__CallerIsNotChallenger();
        }

        // £checked: is with timestamp, gaming timestamp and how they work on different chains. 
        // £skipped: RamIsNotSelected and this if function are mutually exclusive. -- medium because function has no impact on broader protocol. 
        // skipped because not true: this function CAN be called. 
        // Meaning that this function can NEVER be called.
        // £logged on Arbitrum timestamp can 24 hours off. right?  
        if (block.timestamp > 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamFinish();
        }
        
        // ££report-written: this is not random. 
        uint256 random =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2; // £note / £audit low?: this should be 1? now chance is not 50 / 50?   

        // £logged: this should be a mapping (or enum -> just add value of 1 each time: as the increase in power is ordinal). -- or: mapping! See elsewhere: change function accordingly. 
        // £skipped?: slither: Reentrancy in ChoosingRam.increaseValuesOfParticipants(uint256,uint256) (src/ChoosingRam.sol#37-99): 
        // £skipped?: is this really an issue here? Would be interesting to try and exploit it. 
        // £ it might be possible to re-enter and in one go upgrade all the way. -- maybe mention in passing? // when proposed remedy? 
        if (random == 0) {
            if (ramNFT.getCharacteristics(tokenIdOfChallenger).isJitaKrodhah == false){
                ramNFT.updateCharacteristics(tokenIdOfChallenger, true, false, false, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfChallenger).isDhyutimaan == false){
                ramNFT.updateCharacteristics(tokenIdOfChallenger, true, true, false, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfChallenger).isVidvaan == false){
                ramNFT.updateCharacteristics(tokenIdOfChallenger, true, true, true, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfChallenger).isAatmavan == false){
                ramNFT.updateCharacteristics(tokenIdOfChallenger, true, true, true, true, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfChallenger).isSatyavaakyah == false){
                ramNFT.updateCharacteristics(tokenIdOfChallenger, true, true, true, true, true);
                // £checked WHAT?! is selectedRam set here as well?! YEP  
                // £skip: it allows for selectedRam to be set AFTER selectRamIfNotSelected has been called. 
                // No, because of the RamIsNotSelected modifier this is not possible. 
                // £question: than how can it matter... 
                selectedRam = ramNFT.getCharacteristics(tokenIdOfChallenger).ram;
            }
        } else {
            if (ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).isJitaKrodhah == false){
                ramNFT.updateCharacteristics(tokenIdOfAnyPerticipent, true, false, false, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).isDhyutimaan == false){
                ramNFT.updateCharacteristics(tokenIdOfAnyPerticipent, true, true, false, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).isVidvaan == false){
                ramNFT.updateCharacteristics(tokenIdOfAnyPerticipent, true, true, true, false, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).isAatmavan == false){
                ramNFT.updateCharacteristics(tokenIdOfAnyPerticipent, true, true, true, true, false);
            } else if (ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).isSatyavaakyah == false){
                ramNFT.updateCharacteristics(tokenIdOfAnyPerticipent, true, true, true, true, true);
                // checked. WHAT?! is selectedRam set here as well?! YEP 
                // £skip: it allows for selectedRam to be set AFTER selectRamIfNotSelected has been called.
                // No, because of the RamIsNotSelected modifier this is not possible. 
                selectedRam = ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).ram;
            }
        }
    }

    // £info: this function selects a ram supposedly randomly.
    // £logged: note that date is a magic number! 
    // £logged: if organiser waits till the last minute to select ram, there is only 69 seconds left to call killRavana. 
    // £ (max is 24 hours) -- see notes.md 
    // £checked how much time is there to call this function? CHECK! 
    function selectRamIfNotSelected() public RamIsNotSelected OnlyOrganiser {
        if (block.timestamp < 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamIsNotFinish();
        }
        // £logged (centralisation?) if organiser does not pick before certain time, participants will not be able to claim reward. 
        if (block.timestamp > 1728777600) {
            revert ChoosingRam__EventIsFinished();
        }
        // £report-written: again, this is not random. 
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();
        //: £logged-H-6 do not need two separate state variables for this. -- allows for resetting selectedRam
        selectedRam = ramNFT.getCharacteristics(random).ram;
        // £logged: needs to emit event
        isRamSelected = true;
    }

    
}

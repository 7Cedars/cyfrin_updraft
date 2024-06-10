// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RamNFT} from "./RamNFT.sol";

contract ChoosingRam {
    // £checked: how many events need to be added? 
    // £audit-low/info again: include (indexed) vars in errors and events.   
    error ChoosingRam__InvalidTokenIdOfChallenger();
    error ChoosingRam__InvalidTokenIdOfPerticipent();
    error ChoosingRam__TimeToBeLikeRamFinish();
    error ChoosingRam__CallerIsNotChallenger();
    error ChoosingRam__TimeToBeLikeRamIsNotFinish();
    error ChoosingRam__EventIsFinished();

    bool public isRamSelected; // needs to be public 
    RamNFT public ramNFT; // can be internal? 

    address public selectedRam; // needs to be public 

    // seems ok... 
    modifier RamIsNotSelected() {
        require(!isRamSelected, "Ram is selected!");
        _;
    }

    // £audit low: modifier only used once. Integrate into function. 
    modifier OnlyOrganiser() {
        require(ramNFT.organiser() == msg.sender, "Only organiser can call this function!");
        _;
    }

    constructor(address _ramNFT) {
        // £audit-gas - no need to initialise state vars to false.  
        isRamSelected = false; 
        // £audit-high/medium? No address(0) check.. or ANYTHING else. it is not event set as ERC721. This can be literally any kind of contract. 
        ramNFT = RamNFT(_ramNFT);  
    }
      
    // £notice: this function raises value of either tokenIdOfChallenger OR tokenIdOfAnyPerticipent.
    // £audit-info: this functionality of the contract does not have any influence over broader protocol. It is useless. 
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

        // £info: is with timestamp, gaming timestamp and how they work on different chains. 
        // £audit-medium: RamIsNotSelected and this if function are mutually exclusive. -- medium because function has no impact on broader protocol. 
        // Meaning that this function can NEVER be called.    
        if (block.timestamp > 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamFinish();
        }
        
        // £audit-high: this is not random. 
        uint256 random =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2; // £note / audit low?: this should be 1? now chance is not 50 / 50?   

        // audit-gas: this should be a mapping (or enum -> just add value of 1 each time: as the increase in power is ordinal). -- or: mapping! See elsewhere: change function accordingly. 
        // £audit?: slither: Reentrancy in ChoosingRam.increaseValuesOfParticipants(uint256,uint256) (src/ChoosingRam.sol#37-99): 
        // £audit?: is this really an issue here? Would be interesting to try and exploit it. 
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
                // £audit-high: it allows for selectedRam to be set AFTER selectRamIfNotSelected has been called. 
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
                // £audit-high: it allows for selectedRam to be set AFTER selectRamIfNotSelected has been called.   
                selectedRam = ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).ram;
            }
        }
    }

    // £info: this function selects a ram supposedly randomly.
    // £audit: note that date is a magic number! 
    // £audit-low: if organiser waits till the last minute to select ram, there is only 69 seconds left to call killRavana. 
    // £ (max is 24 hours) -- see notes.md 
    // £checked how much time is there to call this function? CHECK! 
    function selectRamIfNotSelected() public RamIsNotSelected OnlyOrganiser {
        if (block.timestamp < 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamIsNotFinish();
        }
        // £audit (centralisation?) if organiser does not pick before certain time, participants will not be able to claim reward. 
        if (block.timestamp > 1728777600) {
            revert ChoosingRam__EventIsFinished();
        }
        // £audi high: again, this is not random. 
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();
        // £audit-gas/low do not need two separate state variables for this.
        selectedRam = ramNFT.getCharacteristics(random).ram;
        // £audit-info: needs to emit event
        isRamSelected = true;
    }
}

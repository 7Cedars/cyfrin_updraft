// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RamNFT} from "./RamNFT.sol";

contract ChoosingRam {
    error ChoosingRam__InvalidTokenIdOfChallenger();
    error ChoosingRam__InvalidTokenIdOfPerticipent();
    error ChoosingRam__TimeToBeLikeRamFinish();
    error ChoosingRam__CallerIsNotChallenger();
    error ChoosingRam__TimeToBeLikeRamIsNotFinish();
    error ChoosingRam__EventIsFinished();

    bool public isRamSelected;
    RamNFT public ramNFT;

    address public selectedRam;

    modifier RamIsNotSelected() {
        require(!isRamSelected, "Ram is selected!");
        _;
    }

    modifier OnlyOrganiser() {
        require(ramNFT.organiser() == msg.sender, "Only organiser can call this function!");
        _;
    }

    constructor(address _ramNFT) {
        isRamSelected = false;
        ramNFT = RamNFT(_ramNFT);
    }
    
    // NB: £audit-info all natspec are missing. Hence very confusing....  
    // @notice: this function raises value of either tokenIdOfChallenger OR tokenIdOfAnyPerticipent. 
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

        // £info: is with timestamp, gaming timestamp and how they work on different chains. 
        // £audit-medium: RamIsNotSelected and this if function are mutually exclusive. 
        // Meaning that this function can NEVER be called.    
        if (block.timestamp > 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamFinish();
        }
        
        // £audit-high: this is not random. 
        uint256 random =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;

        // £q: is not not super gas inefficient?! 
        // £q: what is actually happening here? 
        // £answer: This is where ramNft can be increased in power / characteristics. 
        // £note: but look at how this is done... it just just amazingly stupidly gas inefficient. 
        // audit-gas: this should be an enum. and just add value of 1 each time: as the increase in power is linear. 
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
                // £question. WHAT?! is selectedRam set here as well?! 
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
                // £question. WHAT?! is selectedRam set here as well?! 
                // £question: it does NOT set isRamSelected = true; How does this impact protocol? 
                // £ one way is that it allows for front runnign: setting selectedRam AFTER selectRamIfNotSelected has been called. 
                // £note: this also applies to the bit above.   
                selectedRam = ramNFT.getCharacteristics(tokenIdOfAnyPerticipent).ram;
            }
        }
    }

    // £info: this function selects a ram supposedly randomly.
    // £audit: note that date is a mgic number! 
    // £question: do all these number actually align?! (prob not...)  
    // £question how much time is there to call this function? CHECK!  
    function selectRamIfNotSelected() public RamIsNotSelected OnlyOrganiser {
        if (block.timestamp < 1728691200) {
            revert ChoosingRam__TimeToBeLikeRamIsNotFinish();
        }
        if (block.timestamp > 1728777600) {
            revert ChoosingRam__EventIsFinished();
        }
        // £audi high: again, this is not random. 
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();
        // £audit-info do not need two separate state variables for this.
        selectedRam = ramNFT.getCharacteristics(random).ram;
        isRamSelected = true;
    }
}

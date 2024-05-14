// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
// £report-written use floating pragma is discouraged. Exact version better. -- 
// £report-written: why use old version of solidity? 

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "lib/base64/base64.sol";

//£audit Many functions lack emit events. 

/// @title PuppyRaffle
/// @author PuppyLoveDAO
/// @notice This project is to enter a raffle to win a cute dog NFT. The protocol should do the following:
/// 1. Call the `enterRaffle` function with the following parameters:
///    1. `address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.
/// 2. Duplicate addresses are not allowed
/// 3. Users are allowed to get a refund of their ticket & `value` if they call the `refund` function
/// 4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy
/// 5. The owner of the protocol will set a feeAddress to take a cut of the `value`, and the rest of the funds will be sent to the winner of the puppy.
contract PuppyRaffle is ERC721, Ownable {
    using Address for address payable;

    uint256 public immutable entranceFee; //£ should be named something like i_entranceFee

    address[] public players;
    // following should be immutable - as it does not change throughout contract. 
    uint256 public raffleDuration;
    uint256 public raffleStartTime;
    address public previousWinner;

    // We do some storage packing to save gas £check - unsafe?  
    address public feeAddress;
    uint64 public totalFees = 0;

    // mappings to keep track of token traits
    mapping(uint256 => uint256) public tokenIdToRarity;
    mapping(uint256 => string) public rarityToUri;
    mapping(uint256 => string) public rarityToName;

    // Stats for the common puppy (pug)
    string private commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
    uint256 public constant COMMON_RARITY = 70;
    string private constant COMMON = "common";

    // Stats for the rare puppy (st. bernard)
    // £report-written: uri's should be saved as constants
    string private rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
    uint256 public constant RARE_RARITY = 25;
    string private constant RARE = "rare";

    // Stats for the legendary puppy (shiba inu)
    string private legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
    uint256 public constant LEGENDARY_RARITY = 5;
    string private constant LEGENDARY = "legendary";

    // Events
    event RaffleEnter(address[] newPlayers);
    event RaffleRefunded(address player);
    event FeeAddressChanged(address newFeeAddress);

    /// @param _entranceFee the cost in wei to enter the raffle
    /// @param _feeAddress the address to send the fees to
    /// @param _raffleDuration the duration in seconds of the raffle
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
        entranceFee = _entranceFee;
        //£report-written check for zero address in next line (slither).  
        // (= input validation)
        feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;
        raffleStartTime = block.timestamp;

        rarityToUri[COMMON_RARITY] = commonImageUri;
        rarityToUri[RARE_RARITY] = rareImageUri;
        rarityToUri[LEGENDARY_RARITY] = legendaryImageUri;

        rarityToName[COMMON_RARITY] = COMMON;
        rarityToName[RARE_RARITY] = RARE;
        rarityToName[LEGENDARY_RARITY] = LEGENDARY;
    }

    /// @notice this is how players enter the raffle
    /// @notice they have to pay the entrance fee * the number of players
    /// @notice duplicate entrants are not allowed
    /// @param newPlayers the list of players to enter the raffle
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
        }
        // Check for duplicates
        // £audit the Check should be BEFORE adding new players to memory. -- this enables duplicates to be entered. 
        // only thing that will not happen is emitting event. 
        // £audit: Denial-of-Service bug 
        // £report-written: cache lenght of array, otherwise it will constantly call storage, whcih is really gas intensive.    
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }

    /// @param playerIndex the index of the player to refund. You can find it externally by calling `getActivePlayerIndex`
    /// @dev This function will allow there to be blank spots in the array
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        //£audit: player 0 can never refund!! (I think this is the massive bug that is mentioned in the video...)
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        // £written: here the sequence is incorrect (not CEI)=> reentrancy attack vulnerability. Switch following two sentences? 
        payable(msg.sender).sendValue(entranceFee);
        players[playerIndex] = address(0);

        // £question: so this emit can be influeced - through reentrency attack above? 
        // £written: low.  
        emit RaffleRefunded(playerAddress);
    }

    /// @notice a way to get the index in the array
    /// @param player the address of a player in the raffle
    /// @return the index of the player in the array, if they are not active, it returns 0
    // £audit: gas issue: use of array and then loop is inefficient. Same functionality is possible with mapping. Use that 
    function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
        // £audit if the player is at index 0... they will think thet are inactive.  
        return 0;
    }

    /// @notice this function will select a winner and mint a puppy
    /// @notice there must be at least 4 players, and the duration has occurred
    /// @notice the previous winner is stored in the previousWinner variable
    /// @dev we use a hash of on-chain data to generate the random numbers
    /// @dev we reset the active players array after the winner is selected
    /// @dev we send 80% of the funds to the winner, the other 20% goes to the feeAddress
    // £audit! this fucntion can be called by anyone. -- it is possible to have it revert if you don't like the outcome!  
    // 
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        // £audit: the docs do NOT mention that it has a minimum amount of 4 players. Documentation issue.  
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        // £audit: NOT RANDOM. Classic. -- needs oracle. Chainlink VRF 
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        // £q Why not just balance? -- leave this as question for now. but likely an £audit issue - see issues below.  
        uint256 totalAmountCollected = players.length * entranceFee;
        // £audit! precision loss is an issue here! Actually... 
        // £audit-info avoid magic numbers: include public constants with clear descriptors. 
        uint256 prizePool = (totalAmountCollected * 80) / 100; // £ correct? prizepool 
        // £question: can this line potetnially break withdraw function? check and build PoC!    
        uint256 fee = (totalAmountCollected * 20) / 100;
        // The total fees that can be collected by owner. £audit: overflow bug. 
        // additional £audit: this is an unsafe casting of uint256 to uint64! 
        totalFees = totalFees + uint64(fee);

        // often used with ERC-721 tokens. -- £question for self: does not exist in ERC-1155... right? 
        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
        // £audit randomness is also problem here. 
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }
        
        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        
        // £audit: CEI sequence here also a problem? reentrancy attack? -- the require statement comes way at the end. 
        // £audit can you create an external contract that reverts if you do not like winner? YES :D 
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }

    /// @notice this function will withdraw the fees to the feeAddress
    // £audit: this function can be called by anyone. problem? or just annoying? 
    function withdrawFees() external {
        // £audit NB! this will hang BECAUSE of overflow bug! - require function does not check what it should be checking... 
        // £question: the impricision issue will also crash this? 
        // £audit: mishandling eth: with a self destruct function in external function, you can force eth into another contract. 
        // See SelfDestructMe in SC-Exploits-Minimized
        // if breaks this require, resulting in a DoS :no-one will be able to withdraw fees. 
        require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        // £what if feeAddress is contract with poor fallback? 
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }

    /// @notice only the owner of the contract can change the feeAddress
    /// @param newFeeAddress the new address to send fees to
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }

    /// @notice this function will return true if the msg.sender is an active player
    // £audit: this function is not used anywhere! 
    // - severity = none; but informational. 
    function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    /// @notice this could be a constant variable
    function _baseURI() internal pure returns (string memory) {
        return "data:application/json;base64,";
    }

    /// @notice this function will return the URI for the token
    /// @param tokenId the Id of the NFT
    // ... £ok, this is a evry strange way of doing this. -- it's because they are dynamic. 
    // £audit: gas issue? 
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "PuppyRaffle: URI query for nonexistent token");

        uint256 rarity = tokenIdToRarity[tokenId];
        string memory imageURI = rarityToUri[rarity];
        string memory rareName = rarityToName[rarity];

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes( // £question: is this redundant? 
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '", "description":"An adorable puppy!", ',
                            '"attributes": [{"trait_type": "rarity", "value": ',
                            rareName,
                            '}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }
}

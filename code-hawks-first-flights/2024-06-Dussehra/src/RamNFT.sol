// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// audit: remove unused imports. 
// audit: it is an NFT... without an NFT.
import {ERC721URIStorage, ERC721} from "@openzeppelin/token/ERC721/extensions/ERC721URIStorage.sol";
// £audit: NB TLOAD and TSTORE are NOT supported by zksync, but ARE used by openZeppelin v5 and up! 
// = transient storage....  See https://www.rollup.codes/zksync-era 
// with arbitrum this is NOT a problem. 

// £info ERC721 can be used on all these chains? . 
// £checked: does seem so... do ERC721s work on all selected chains?  
contract RamNFT is ERC721URIStorage {
    error RamNFT__NotOrganiser();
    error RamNFT__NotChoosingRamContract();

    // checked: how many events need to be added? 

    // https://medium.com/illumination/16-divine-qualities-of-lord-rama-24c326bd6048
    // £info: these are the characteristics of ram. 
    // £info: in function increaseValueParticipants these characteristics are added. 
    // but there are done in an ordinal (not nominal) approach. It means they are ranked. 
    // should be a mapping I think (enum is also possible, but I think it is meant to be nominal, not ordinal).
    // struct CharacteristicsOfRam {
    // address ram;
    // mapping string characteristic => bool. 
    // }

    struct CharacteristicsOfRam {
        address ram;
        bool isJitaKrodhah;
        bool isDhyutimaan;
        bool isVidvaan;
        bool isAatmavan;
        bool isSatyavaakyah;
    }

    uint256 public tokenCounter; // £audit-medium / high: does not have 0. => calculation of fees will FAIL because of this!  
    address public organiser; // £audit-low / info should be immutable. NOT private! HAS to be public.  
    address public choosingRamContract;  // £audit-high should be immutable - audit is together with function below.  

    // seems ok. 
    mapping(uint256 tokenId => CharacteristicsOfRam) public Characteristics;

    // seems ok. 
    modifier onlyOrganiser() {
        if (msg.sender != organiser) { // £checked: how is organiser set? A: at construction.  
            revert RamNFT__NotOrganiser();
        }
        _;
    }

    // check if call comes from external contract. 
    // £audit-info this modifier is only called once. Can be inserted into function itself. 
    modifier onlyChoosingRamContract() {
        if (msg.sender != choosingRamContract) { // £note: choosingRamContract is issue (see below). 
            revert RamNFT__NotChoosingRamContract();
        }
        _;
    }

    // constructor function. - checked. 
    constructor() ERC721("RamNFT", "RAM") {
        tokenCounter = 0; // £audit-gas? unnecessary initiation. when initialising a state var, it initialises to 0. 
        // £checked: organiser is set at ramNFT contract (not Dussehra). Is that an issue? - actually it is set twice. this is still an open question. 
        // £checked: Who is msg.sender here?! -- can be anyone - also smart contract. (it is not created by the Dussehra.)
        
        // £audit-info: needs to emit event
        organiser = msg.sender;
    }

    // £audit check on contract missing. ALSO NO TIME/ DATE check! No check whatsoever. You can add any contract you want.  
    // audit: slither: lacks zero check :D not just that...
    // needs to be in constructor... but isn't. 
    // btw: this contract can be changed AT ANY TIME!!!! (rug pull possible => YES)
    // THIS NEEDS TO BE TAKEN FROM DUSSEHRA CONTRACT.
    // £audit-high: what is worse the choosingRam contratc collects the fees! you collect the fees... change the contract and RUN.  
    // £audit-medium/high YEP: choosing ram selects who gets to be Ram, another contract can set this to a fixed contract. 
    // £audit-low/info: slither should emit event. does not. 
    // £checked slither-low: Reentrancy in RamNFT.mintRamNFT(address) (src/RamNFT.sol#56-68):
    // £checked: is this an issue, or not? Don't think so. 
    function setChoosingRamContract(address _choosingRamContract) public onlyOrganiser {
        // £audit-info: needs to emit event
        choosingRamContract = _choosingRamContract;
    }
    
    // mints ramNFT, initialises characteristics 
    // £audit-info: needs to emit event
    function mintRamNFT(address to) public {
        // £audit-high: tokenId starts at 1, not 0. this cause TWO problems:  
        // 1: What happens if token 0 is selected in random select ram? - I think contract gets stuck. 
        // 2: £ qurstion: does the fee amount collected & length of ramNft not align..   
        uint256 newTokenId = tokenCounter++;
        _safeMint(to, newTokenId); // = internal function. 

        //£audit-gas? I assume this take a lot of gas. Better to use mapping. (see also notes above.)  
        //£audit-gas? also: fo they not initialise automatically to false?! the only initialisation you need to do is `ram: to`! 
        Characteristics[newTokenId] = CharacteristicsOfRam({
            ram: to, // this initialises as addresss(0) - you DO need to set this. 
            isJitaKrodhah: false, // this initialises as false, no need to set as such. 
            isDhyutimaan: false, // this initialises as false, no need to set as such. 
            isVidvaan: false, // this initialises as false, no need to set as such. 
            isAatmavan: false, // this initialises as false, no need to set as such. 
            isSatyavaakyah: false // this initialises as false, no need to set as such. 
        });
    }

    // takes characteristics and updates them. 
    // £audit-gas: you ONLY have to set the charateristic that is changing. 
    // so... uint256 tokenId and string characteristic for the one to be updated. 
    // then just set it to what it is not.  
    // £audit-info: needs to emit event
    function updateCharacteristics(
        uint256 tokenId,
        bool _isJitaKrodhah,
        bool _isDhyutimaan,
        bool _isVidvaan,
        bool _isAatmavan,
        bool _isSatyavaakyah
    ) public onlyChoosingRamContract {
        // £audit-medium / high: organiser can reset / change addresses linked to RamNFTs.   
        // choosingRamContract can be set bu organiser to any address (does not have to be ChoosingRam contract)
        // this will allow the organiser to set address of NFTRam to their address and steal all funds. 
        Characteristics[tokenId] = CharacteristicsOfRam({
            ram: Characteristics[tokenId].ram,
            isJitaKrodhah: _isJitaKrodhah,
            isDhyutimaan: _isDhyutimaan,
            isVidvaan: _isVidvaan,
            isAatmavan: _isAatmavan,
            isSatyavaakyah: _isSatyavaakyah
        });
    }

    // £audit-low public state vars have getter function of themselves - no need need to add one.  
    function getCharacteristics(uint256 tokenId) public view returns (CharacteristicsOfRam memory) {
        return Characteristics[tokenId];
    }
    
    // £audit-low public state vars have getter function of themselves - no need need to add one. 
    function getNextTokenId() public view returns (uint256) {
        return tokenCounter;
    }
}

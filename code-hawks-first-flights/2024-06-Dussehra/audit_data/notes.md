# About 
It has a nice Hindu context story. 

£audit BNB is being sunset! 
£audit zksync does NOT support transient storage! 

Three contracts: 
- `ChoosingRam` 
  - This allows people to create a ram character. I think. Not entirely clear. 
  - allows users to 'increase their value'. - £checked add characteristics: what is meant by this? 
  - if the user has not selected Ram before 12th October 2024 then, Organiser can select Ram if not selected. (what does this mean? £checked: how is date calculated? = block time)
  - functions
    - `increaseValuesOfParticipants` - Allows users to increase their values (or characteristics) 
    - `selectRamIfNotSelected` - Allows the organiser to select Ram if not selected by the user.
      - £checked: access control issue? - not directly it seems
- `Dussehra` 
  - this is holds actual action of event. (try and?) kill Ravana?    
  - functions: 
    - `enterPeopleWhoLikeRam` - allows users to enter event, by paying fee. They receive ramNFT as they do so.  
      - £checked: how is this fee paid? some vulnerability here?  
      - £checked: is it possible to receive ramNFT without paying fee?
    - `killRavana` allows users to kill Ravana and Organiser will get half of the total amount collected in the event. this function will only work after 12th October 2024 and before 13th October 2024.
      - £checked: what is an 'event' here: whenever user kills ravana? 
      - £checked: how are fees set / calculated? - they are set at construction time.  
      - £checked: how are fees send to organiser - weakness here? - yes: rounding error weakness. I think 
      - £checked: how does date work? if weakness here, can brick whole protocol. -- indeed possibly a weakness. Will get to that when going through code.  
    - `withdraw` - Allows ram to withdraw their rewards.
      - .. clear functionality. 
      - £checked: let's see if withdraw can be hacked. -- rounding error problem. + can be rug pulled :D 
- `RamNFT`
  - Allows the Dussehra contract to mint Ram NFTs, update the characteristics of the NFTs, and get the characteristics of the NFTs
  - How / where are these characteristics saved? on or off-chain? 
  - functions: 
    - `setChoosingRamContract` - Allows the organiser to set the choosingRam contract.
      £checked - can this be hacked? setting of external contract?  - YEP. no checks at all  
    - `mintRamNFT` - Allows the Dussehra contract to mint Ram NFTs.
    - `updateCharacteristics` - Allows the ChoosingRam contract to update the characteristics of the NFTs. 
    - `getCharacteristics` - Allows the user to get the characteristics of the NFTs.
    - `getNextTokenId` - Allows the users to get the next token id.
      - £checked: the user sets next token id? -- no: set when NFT is minted. But no 0 token! 

# notes
Hardly any tests. No fuzz tests, no invariant tests. 

# Sequence
1. RamNFT.sol - CHECK 
2. Dussehra.sol - CHECK
3. ChoosingRam.sol - 

# Potential Attack Vectors 
- see long list above. 

# Questions 
- £checked I am not quite sure how the contract really works yet. What is input user versus organizer  /Dushera contract?
- £checked No: one ram is selected... that person gets ETH. 
- £checked Mocks are placed in src folder. this is not best practice... right? True. but technically not in scope.   
- £checked when are onlyOrganiser and onlyChoosingRamContract called / used? 
- £checked setChoosingRamContract: does it have a check on what kind of contract is added? Don't think so.. Exactly. NOPE. 
-  
  
`ChoosingRam.sol`
  `increaseValuesOfParticipants`
  if (block.timestamp > 1728691200) {
      revert ChoosingRam__TimeToBeLikeRamFinish();
  }

  `selectRamIfNotSelected`
  if (block.timestamp < 1728691200) {
      revert ChoosingRam__TimeToBeLikeRamIsNotFinish();
  }

  if (block.timestamp > 1728777600) {
      revert ChoosingRam__EventIsFinished();
  }

`Dussehra.sol`
  `killRavana` (note modifier: RamIsSelected)
  if (block.timestamp < 1728691069) {
      revert Dussehra__MahuratIsNotStart();
  }
  if (block.timestamp > 1728777669) {
      revert Dussehra__MahuratIsFinished();
  }

  Note difference between earliest moment that Ram can be selected in killRavana = 24 hours. 
  Note difference between latest moment that Ram can be selected in killRavana = 69 seconds. 

  About having two different organisers... 
  -- the Dussehra contract will send funds to whoever initiated the contract. 
  -- 
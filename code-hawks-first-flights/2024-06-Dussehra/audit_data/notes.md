# About 
It has a nice Hindu context story. 

Three contracts: 
- `ChoosingRam` 
  - This allows people to create a ram character. I think. Not entirely clear. 
  - allows users to 'increase their value'. - £q: what is meant by this? 
  - if the user has not selected Ram before 12th October 2024 then, Organiser can select Ram if not selected. (what does this mean? £q: how is date calculated?)
  - functions
    - `increaseValuesOfParticipants` - Allows users to increase their values (or characteristics) 
      - £q What does characters do?!
      - How / why increased?  
    - `selectRamIfNotSelected` - Allows the organiser to select Ram if not selected by the user.
      - £q: access control issue? 
- `Dussehra` 
  - this is holds actual action of event. (try and?) kill Ravana?    
  - functions: 
    - `enterPeopleWhoLikeRam` - allows users to enter event, by paying fee. They receive ramNFT as they do so.  
      - £q: how is this fee paid? some vulnerability here?  
      - £q: is it possible to receive ramNFT without paying fee?
    - `killRavana` allows users to kill Ravana and Organiser will get half of the total amount collected in the event. this function will only work after 12th October 2024 and before 13th October 2024.
      - £q: what is an 'event' here: whenever user kills ravana? 
      - £q: how are fees set / calculated? 
      - £q: how are fees send to organiser - weakness here? 
      - £again: how does date work? if weakness here, can brick whole protocol. 
    - `withdraw` - Allows ram to withdraw their rewards.
      - .. clear functionality. 
      - £q: let's see if withdraw can be hacked :) 
- `RamNFT`
  - Allows the Dussehra contract to mint Ram NFTs, update the characteristics of the NFTs, and get the characteristics of the NFTs
  - How / where are these characteristics saved? on or off-chain? 
  - functions: 
    - `setChoosingRamContract` - Allows the organiser to set the choosingRam contract.
      - can this be hacked? setting of external contract?   
    - `mintRamNFT` - Allows the Dussehra contract to mint Ram NFTs.
    - `updateCharacteristics` - Allows the ChoosingRam contract to update the characteristics of the NFTs. 
    - `getCharacteristics` - Allows the user to get the characteristics of the NFTs.
    - `getNextTokenId` - Allows the users to get the next token id.
      - £q: the user sets next token id? 

# notes
Hardly any tests. No fuzz tests, no invariant tests. 

# Sequence
1. RamNFT.sol
2. Dussehra.sol
3. ChoosingRam.sol

# Potential Attack Vectors 
- see long list above. 

# Questions 
- £question I am not quite sure how the contract really works yet. What is input user versus organizer  /Dushera contract?
- £question Is there on ram or multiple? Answer: multple. everyone that has a ramNFT is ram.
- £question Mocks are placed in src folder. this is not best practice... right?  
- £when are onlyOrganiser and onlyChoosingRamContract called / used? 
- £setChoosingRamContract: does it have a check on what kind of contract is added? Don't think so.. 
-  
  

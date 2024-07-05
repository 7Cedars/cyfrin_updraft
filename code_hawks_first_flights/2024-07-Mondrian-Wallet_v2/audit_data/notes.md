# About 
It is a straightforward abstracted account. Supposed to be able to interact with two different _system_ contracts. 

The description is one sentence: 
- "The Mondrian Wallet v2 will allow users to have a native smart contract wallet on zkSync, it will implement all the functionality of `IAccount.sol`." - that's it. 
- `IAccount.sol` is imported from `foundry-era-contracts@0.0.3`. 


# notes
Three main topics are mentioned: 
- Account Abstraction => issues with signatures, role based access? 
- zkSync System Contracts => issue with calling these system contracts
- Upgradable smart contracts via UUPS 
  - issues with memory slots? - nope. There are no memory slots. 
  - Possible issue: upgrading is done via a system contract. (just as deploying contracts..) See https://docs.zksync.io/build/zksync-101/upgrading
  - Also.. what is the proxy?! the upgrade logic is completely off / bonkers. 
- Interacting with system contracts was an issue in zksync... right? Check. 
- Check if all system addresses are correct.
- `user` as role is not defined? Interesting.
- Invariants that need to hold? 
  - Only owner can upgrade. 
  - Only validated user (or only owner? No user role defined..) can make transaction - no one else.
    - NB: from README.md: 
      - "Mondrian Wallet v2 will allow **users **to have a native smart contract wallet on zkSync, it will implement all the functionality of `IAccount.sol`." 
      - The wallet should be able to do anything a normal EoA can do, but **with limited functionality interacting with system contracts**.  
      - `Owner` - The owner of the wallet, who can upgrade the wallet.
- 

# Sequence


# Potential Attack Vectors 


# Questions 
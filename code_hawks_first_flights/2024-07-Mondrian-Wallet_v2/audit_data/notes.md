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
- Interesting: coverage does not work because "stack too deep". Is this something common with zksync? 
- 

# Potential security risks / Questions (to double check while identifying vulnerabilities)
- `DEPLOYER_CONTRACT` and the `NONCE_HOLDER_SYSTEM_CONTRACT` are the systems the contracts is supposed to work with. (because: nonce and upgrade!) Is this actually the case? can it be broken? 
  - There are a list of system contracts in zksync. for UPGRADING contracts there is a specific one. Which one? check! (pretty sure it is not `DEPLOYER_CONTRACT`)
-  CHECKED. INDEED ISSUE. Is there a payable receive function?! 
-  CHECKED. INDEED ISSUE. NO Asssembly calls. I now for a fact there was - somewhere - some assembly that needed to be done. Where? 
-  Can execute transaction be called by anyone? Double check 
-  Is payment sequence properly implemented 
-  Does authorizeUpgrade have any checks? 
   -  If not, then anyone, at anytime, can break the wallet. 
-  How is address recover managed? 
-  CHECKED. SEEMS OK. Overflow / underflow issues? (is safecast used where it is supposed to be used?) 
-  CHECKED. SEEMS OK. SLITHER-HIGH: MondrianWallet2._executeTransaction(Transaction) (src/MondrianWallet2.sol#150-166) sends eth to arbitrary user
   -  Indeed an issue? check! 
-  SLITHER MEDIUM: MemoryTransactionHelper._encodeHashLegacyTransaction(Transaction).encodedChainId (lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol#198) is a local variable never initialized
   -  This is in a helper contract. But still. Worth checking out? 
-  CHECKED SEEMS OK. SLITHER MEDIUM: 
   -  MondrianWallet2._validateTransaction(Transaction) (src/MondrianWallet2.sol#124-148) ignores return value by SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()()),address(NONCE_HOLDER_SYSTEM_CONTRACT),0,abi.encodeCall(INonceHolder.incrementMinNonceIfEquals,(_transaction.nonce))) (src/MondrianWallet2.sol#125-130) 
   -  MondrianWallet2._executeTransaction(Transaction) (src/MondrianWallet2.sol#150-166) ignores return value by SystemContractsCaller.systemCallWithPropagatedRevert(gas,to,value,data) (src/MondrianWallet2.sol#157)
   -  In both cases return value is ignored. Is this an issue? Can it be? 
-  CHECKED SLITHER LOW: The following unused import(s) in src/MondrianWallet2.sol should be removed: {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
   -  This points to an issue. Why is MessageHashUtils not used?! -- false positive? Actually not an issue? 
-  There is a renounceOwner function from Ownable. What happens if this is called when thre are still funds in the contract? 
   -  If it is an issue: LOW risk. 
- See function _authorizeUpgrade: can ANYONE call an upgrade? CHECK! 

# Sequence
- [ ] MondrianWallet2.sol
- [ ] Interactions with `DEPLOYER_CONTRACT` 
- [ ] Interactions with `NONCE_HOLDER_SYSTEM_CONTRACT` -- seems ok? 
- [ ] Interactions with other contracts that are missing? 
- [ ] Compare contract with the one I build in the course. See where there are difference from the best practice that one shows.. 

# Potential Risks (identified during scoping)
- £audit-high: upgrade of contract will not work. I do not know yet what the exact description PoC will be. But this is a high risk one. 
- £audit-high: Validation does not work: missing check. 
- £audit-high: execution of transaction needs assembly to work properly. Currently just inserts data field. 
- £audit medium/high: missing receive/fallback function 
- 
- 
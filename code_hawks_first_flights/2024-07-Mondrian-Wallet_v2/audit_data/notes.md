# About 
It is a straightforward abstracted account. Supposed to be able to interact with two different _system_ contracts. 

The description is one sentence: 
- "The Mondrian Wallet v2 will allow users to have a native smart contract wallet on zkSync, it will implement all the functionality of `IAccount.sol`." - that's it. 
- `IAccount.sol` is imported from `foundry-era-contracts@0.0.3`. 

# notes
Three main topics are mentioned: 
- Account Abstraction => issues with signatures, role based access? - YEP  
- zkSync System Contracts => issue with calling these system contracts - NOPE
- Upgradable smart contracts via UUPS 
  - issues with memory slots? - nope. There are no memory slots. 
  - Possible issue: upgrading is done via a system contract. (just as deploying contracts..) See https://docs.zksync.io/build/zksync-101/upgrading
  - Also.. what is the proxy?! the upgrade logic is completely off / bonkers. 
  - After checking.. all this seems ok. 
- Interacting with system contracts was an issue in zksync... right? Check. 
  - Yep. see payment issue. checked. 
- Check if all system addresses are correct.
  - checked, correct. 
- `user` as role is not defined? Interesting.
  - not an issue. 
- Invariants that need to hold? 
  - Only owner can upgrade. - Does NOT hold  
  - Only validated user (or only owner? No user role defined..) can make transaction - no one else.
    - NB: from README.md: 
      - "Mondrian Wallet v2 will allow **users **to have a native smart contract wallet on zkSync, it will implement all the functionality of `IAccount.sol`." 
      - The wallet should be able to do anything a normal EoA can do, but **with limited functionality interacting with system contracts**.  
      - `Owner` - The owner of the wallet, who can upgrade the wallet.
- Interesting: coverage does not work because "stack too deep". Is this something common with zksync? 
- 

# Potential security risks / Questions (in order of to check)
-  CHECKED How is address recover managed? Seems ok. 
- CHECKED `DEPLOYER_CONTRACT` and the `NONCE_HOLDER_SYSTEM_CONTRACT` are the systems the contracts is supposed to work with. (because: nonce and upgrade!) Is this actually the case? can it be broken? done't think so.  
  - There are a list of system contracts in zksync. for UPGRADING contracts there is a specific one. Which one? check! (pretty sure it is not `DEPLOYER_CONTRACT`)
- CHECKED Is payment sequence properly implemented - NOPE
- SKIPPED SLITHER MEDIUM: MemoryTransactionHelper._encodeHashLegacyTransaction(Transaction).encodedChainId (lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol#198) is a local variable never initialized
   - This is in a helper contract. But still. Worth checking out? 
- CHECKED See function _authorizeUpgrade: can ANYONE call an upgrade? CHECK! 
  - Does authorizeUpgrade have any checks? 
  -  If not, then anyone, at anytime, can break the wallet.
-  CHECKED. IS OK. Can execute transaction be called by anyone? Double check 
-  CHECKED. INDEED ISSUE. Is there a payable receive function?! 
-  CHECKED. INDEED ISSUE. NO Asssembly calls. I now for a fact there was - somewhere - some assembly that needed to be done. Where?
-  CHECKED. SEEMS OK. Overflow / underflow issues? (is safecast used where it is supposed to be used?) 
-  CHECKED. SEEMS OK. SLITHER-HIGH: MondrianWallet2._executeTransaction(Transaction) (src/MondrianWallet2.sol#150-166) sends eth to arbitrary user
   -  Indeed an issue? check! 
-  CHECKED SEEMS OK. SLITHER MEDIUM: 
   -  MondrianWallet2._validateTransaction(Transaction) (src/MondrianWallet2.sol#124-148) ignores return value by SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()()),address(NONCE_HOLDER_SYSTEM_CONTRACT),0,abi.encodeCall(INonceHolder.incrementMinNonceIfEquals,(_transaction.nonce))) (src/MondrianWallet2.sol#125-130) 
   -  MondrianWallet2._executeTransaction(Transaction) (src/MondrianWallet2.sol#150-166) ignores return value by SystemContractsCaller.systemCallWithPropagatedRevert(gas,to,value,data) (src/MondrianWallet2.sol#157)
   -  In both cases return value is ignored. Is this an issue? Can it be? 
-  CHECKED SLITHER LOW: The following unused import(s) in src/MondrianWallet2.sol should be removed: {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
   -  This points to an issue. Why is MessageHashUtils not used?! -- false positive? Actually not an issue? 
-  CHECKED. INDEED ISSUE. There is a renounceOwner function from Ownable. What happens if this is called when thre are still funds in the contract? 
   -  If it is an issue: LOW risk. 
-  

# Sequence
- [ ] MondrianWallet2.sol
- [x] Interactions with `DEPLOYER_CONTRACT` 
- [x] Interactions with `NONCE_HOLDER_SYSTEM_CONTRACT` -- seems ok? 
- [x] Interactions with other contracts that are missing? 
- [x] Compare contract with the one I build in the course. See where there are difference from the best practice that one shows.. 
- [x] Compare contract with standard one from wizard OpenZeppelin UUPS proxy. See what is different.. 

# Potential Risks (identified during scoping)
- [V1 REPORT DONE] £audit-high: Validation does not work: missing check. Allows anyone to execute any kind of transactions from outside. 
- [V1 REPORT DONE] £audit-high: Anyone can call upgrade function, bricking wallet with false upgrade 
- [V1 REPORT DONE] £audit high: missing receive/fallback function -> means account abstraction will not work. Transactions will not validate. 
- [V1 REPORT DONE] £audit medium: when renouncing ownership, funds will get stuck in contract. They are not returned to owner in case of renounce ownership. 
  - At the moment this is actually NOT an issue, because executeTransactionFromOutside misses a check. 
- [V1 REPORT DONE] £audit-low: constructor is unnecessary. See example zk-sync uups upgradable.
- [V1 REPORT DONE] £audit-medium: payForTransaction does not have access control. 

- NB2! The account should act as an EoA! 
  - See readme: The wallet should be able to do anything a normal EoA can do, but with limited functionality interacting with system contracts. 
  - BUT: IT DOES NOT IMPLEMENT IGNORING DELEGATE CALLS! See DefaultAccount.sol.  
- NB! Anyone can call execute: it break invariant of unique (sender, nonce) pairs. Right?  
- £audit-medium/low: execution of transaction needs assembly to work properly. Currently just inserts data field.  
  - See https://docs.zksync.io/build/developer-reference/ethereum-differences/evm-instructions 
  - The issue is that return values are not checked. But they can grow very large - and eat up gas. 
  - Can I turn this in a big issue?...  
  
- [NOPE] Add lows? 
  - Missing natspecs
  - Poor Readme description. 

# False positive
- £audit-medium: upgrade of contract will not work. I do not know yet what the exact description PoC will be.  -- Actually: upgrade works just fine. It seems. 
- But this remark of PC. Is it just because of the missing function restriction? 


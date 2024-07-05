# next steps / where am I: 
- go through audit items. 
- continue at: -- Read the docs -- 

# INFO: Standard Work flow audit
[ ] Scoping
  [ ] Create an `audit` branch to work in.
    [ ] Copy files from previous audit 
    [ ] Clean up files.  
  [x] Read the docs: get a sense of what the protocol does.
    [x] Are roles defined? 
    [x] Any diagrams? Draw my own? - none. But also does not make a whole lot of sense. Or does it? 
    [x] What are invariants that need to hold? Have they been written out? = see notes
  [x] Read the docs: scope
    [x] is there a commit hash to focus on? = no 
    [x] see what is in and out of scope. = in scope: MondrianWallet2.sol
    [x] Are there known bugs / issues that are out of scope? = see readme: only two system contracts it is supposed to work with. 
      - The wallet may not work as intended with zksync system contracts. The only system contract that it is expected to work correctly with is the `DEPLOYER_CONTRACT` and the `NONCE_HOLDER_SYSTEM_CONTRACT`.
      - We are using the `cyfrin/foundry-era-contracts` package, which is not what the zkSync documentation recommends. Please ignore. 
  [x] Test suite: NB: zksync tests! -- see module I just completed... 
    [x] what is the test coverage? -- unknown. (coverage does not work). But does not seem too good :D 
    [x] unit, fuzz, invariant tests? - only unit. 
  [x] Run `solidity: metrics` on the SRC folder
    [x] Make a check list by complexity. (pincho method) = only one contract :D  
    [x] Check overview of how methods are called. 
    [x] Create sequence of how to review contracts. Where to start, how to continue. Probably simple to complex contracts. 
[ ] Reconnaissance
  [x] Run `slither .` on the code base. Make notes in the code of where issues were flagged.
  [x] Run `aderyn .` on the code base. Make notes in the code of where issues were flagged.
  [ ] Go through code in sequence decided earlier. 
  [ ] Make notes, ask questions... get to know the code. 

[ ] Vulnerability identification: 
  [ ] First pass: Get the attacker mentality started: how to break what I see? 
    [ ] go through questions I created at scoping phase as I do so.  
  [ ] When I think I found one: build PoC and check.
    [ ] If indeed vulnerability, create report item: only title and ref to PoC. (I might find related issues, might get more insight etc.) 
  [ ] The basic things to look out for:
    [ ] Insufficient Access control: Lacking (or wrong) role restrictions. 
    [ ] Governor attacks possible? / Centralization? 
    [ ] Signature Replay? 
    [ ] Incompatibilities between chains? (see https://www.evmdiff.com/)
    [ ] Switched variables in functions being called. 
    [ ] Input (0) checks missing? 
    [ ] Can functions be front run? Can people do something with the knowledge gained from transaction in mempool? 
    [ ] Oracle manipulation?  
    [ ] Poorly implemented randomness? (or more basically: getting info from chain that can only safely be gotten from off-chain)
    [ ] Reentrancy weakness. 
    [ ] With upgradable contracts: Memory overwrites?
  [ ] Second pass: use solodits checklist (https://solodit.xyz/checklist) to go through contract again 

[ ] Reporting
  [ ] See layout in this folder. 
  [ ] Don't start doing this too late: note that well written reports also often get a price + writing up often takes quite some time. 
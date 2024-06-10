[ ] Scoping
  [ ] Read the docs: functionality
    [ ] Are roles defined? 
    [ ] Any diagrams? Draw my own?
    [ ] What are invariants that need to hold? Have they been written out? 
  [ ] Read the docs: scope
    [ ] is there a commit hash to focus on? 
    [ ] see what is in and out of scope. 
    [ ] Are there known bugs / issues that are out of scope? 
  [ ] Test suite: 
    [ ] what is the test coverage?
    [ ] unit, fuzz, invariant tests?   
  [ ] Run `solidity: metrics` on the SRC folder
    [ ] Make a check list by complexity. (pincho method)
    [ ] Check overview of how methods are called. 
    [ ] Create sequence of how to review contracts. Where to start, how to continue. Probably simple to complex contracts. 
[ ] Reconnaissance
  [ ] Create an `audit` branch to work in.  
  [ ] Run `slither .` and `aderyn .` on the code base. Make notes in the code of where issues were flagged.
  [ ] Go through code in sequence decided earlier. 
  [ ] Make notes, ask questions... get to know the code. 

[ ] Vulnerability identification: 
  [ ] First pass: Get the attacker mentality started: how to break what I see? The basic things to look out for:
    [ ] Insufficient Access control: Lacking (or wrong) role restrictions. 
    [ ] Governor attacks possible? / Centralization? 
    [ ] Signature Replay? 
    [ ] Incompatibilities between chains? (see https://www.evmdiff.com/)
    [ ] Switched variables in functions being called. 
    [ ] Input (0) checks missing? 
    [ ] Can functions be front run? Can people do something with the knowledge gained from transaction in mempool? 
    [ ] Oracle manipulation?  
    [ ] Poorly implemented randomness? (or more basically: getting info from chain that can only safely be gotten from off[ ]chain)
    [ ] Reentrancy weakness. 
    [ ] With upgradable contracts: Memory overwrites?
  [ ] When I think I found one: build PoC and check.
    [ ] If indeed vulnerability, create report item: only title and ref to PoC. (I might find related issues, might get more insight etc.) 
  [ ] Second pass: use solodits checklist (https://solodit.xyz/checklist) to go through contract again 

[ ] Reporting
  [ ] See layout in this folder. 
  [ ] Don't start doing this too late: note that well written reports also often get a price.  
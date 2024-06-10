# next steps / where am i: 
- 

# INFO: Standard Work flow audit
[x] Scoping
  [x] Read the docs: get a sense of what the protocol does.
    [x] Are roles defined? 
    [x] Any diagrams? Draw my own? 
    [x] What are invariants that need to hold? Have they been written out?  -- Not that relevant here? there are enough bugs without invariant testing... 
  [x] Read the docs: scope
    [x] is there a commit hash to focus on? = Nope 
    [x] see what is in and out of scope. = files in src 
    [x] Are there known bugs / issues that are out of scope? = none.  
  [x] Test suite: 
    [x] what is the test coverage? = not good, but not terrible either. 
    [x] unit, fuzz, invariant tests? = only unit. 
  [x] Run `solidity: metrics` on the SRC folder
    [x] Make a check list by complexity. (pincho method)
    [x] Check overview of how methods are called. 
    [x] Create sequence of how to review contracts. Where to start, how to continue. Probably simple to complex contracts. 
[x] Reconnaissance
  [x] Create an `audit` branch to work in.  
  [x] Run `slither .` on the code base. Make notes in the code of where issues were flagged.
  [x] Run `aderyn .` on the code base. Make notes in the code of where issues were flagged.
  [x] Go through code in sequence decided earlier. 
  [x] Make notes, ask questions... get to know the code. 

[ ] Vulnerability identification: 
  [ ] First pass: Get the attacker mentality started: how to break what I see? 
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
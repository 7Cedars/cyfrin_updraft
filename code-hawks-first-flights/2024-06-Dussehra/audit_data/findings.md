## High


## Medium


## Low 


## Informational

### [I-1] All functions in all three contracts `ChoosingRam`, `Dussehra` and `RamNFT` are missing NatSpecs. Without NatSpecs it is difficult for auditors and coders alike to understand, increasing the chance of inadvertently missing vulnerabilities or introducing them. 

**Description:** NatSpecs are solidity's descriptions of functions, including their intended functionality, input and output variables. It allows anyone engaging with the code to understand its intended functionality. With this added understanding the chance to accidentally introduce vulnerabilities when refactoring code is reduced. Also, it increases the chance of vulnerabilities being spotted by auditors. 

**Impact** This code base lacks any NatSpecs. As such, code is hard to understand, it is easy to introduce vulnrabilities when refactoring code and harder for auditors to spot vulnerabilities. 

**Recommended Mitigation:** Add NatSpecs to functions. For more information on solidity's NatSpecs, see the [solidity documentation](https://docs.soliditylang.org/en/latest/natspec-format.html).  

### [I-#] The testing suite does not include any fuzz tests, coverage of unit tests can be improved, and naming of tests can be improved. This might have resulted in some bugs not being spotted.

THIS SHOULD BE LAST ONE: TECHNICALLY NOT IN SCOPE. 

**Description:** 
See for instance 
- NFT 0 value.... 

**Recommended Mitigation:** 



### NOTES 
- centralisation is an issue. 
  - setChoosingRamContract has no checks, except that it is onlyOrganiser. I.e.: the organiser can do anything and get away with it. 
- solc version is unsafe? 0.8.20? Better to use 0.8.24? -- slither picked up on this. 
- naming of variables, functions and modifiers is not good. see slither "is not in mixed case" issue. 
- slither: unused imports is an issue.
- slither: immutable state vars is an issue. 
- aderyn: public function should be set as external.  
- aderyn: L-6: Modifiers invoked only once can be shoe-horned into the function
- ALL natspecs are missing


## Gas 

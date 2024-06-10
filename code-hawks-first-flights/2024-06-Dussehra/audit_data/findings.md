## High


## Medium


## Low 


## Informational

- name tests needs to be improved. 
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

1. Convince the protocol that it is an issue. 
2. Argue for severity of issue. 
3. Explain how to fix the issue. 

### [S-#] Storing password on chain makes it visible to anyone, and no longer private. 

**Description:** All on-chain data is visible to anyone, as it can be read directly from blockchain. The `PasswordStore::s_password` variable is intended to be private and only callable through the `PasswordStore::getPassword` function. Instead, s_passowrd is stored on_chain and hence publicly accesible. 

We show one such method of reading any data of chain below. 

**Impact:** Anyone can read the private password, severely breaking the functionality of the protocol. 

**Proof of Concept:**
The below test case shows one method of reading `PasswordStore::s_password` of the blockchain. 

1. create a locally running chain 
```bash 
make anvil
```

2. deploy contract to the chain
```bash
make deploy
```

3. run storage tool 
```bash
cast storage 0x5fbdb2315678afecb367f032d93f642f64180aa3 1
```

4. parse bytes32 storage to string
```bash
cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```

Output: `myPassword`

**Recommended Mitigation:** 
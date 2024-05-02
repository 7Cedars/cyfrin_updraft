### [H-1] Storing password on chain makes it visible to anyone, and no longer private. 

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
The overall architecture needs to be rethought. Storage of any password (and its encoding) need to happen off-chain. 


### [H-2] `PasswordStore::setPassword` has no access control, meaning a non-owner can change the password. 

**Description:** 
The `PasswordStore::setPassword` lacks any access control. It means that any address can call the function and change the password. This is contrary to the natspec that states that `This function allows only the owner to set a new password`. 

```javascript
  function setPassword(string memory newPassword) external {
  @>   //@audit no access control in previous line. 
      s_password = newPassword;
      emit SetNetPassword();
  }
```

**Impact:** Anyone can set the password of the contract, severely breaking intended contract functionality. 

**Proof of Concept:** Add the following to the `PasswordStore.t.sol` test file. 

<details>
<summary> expand code </summary>

```javascript 
  function test_anyone_can_set_password(address randomAddress) public { 
      vm.assume(randomAddress != owner); 
      vm.prank(randomAddress);
      string memory expectedPassword = "myNewPassword"; 

      passwordStore.setPassword(expectedPassword); 

      vm.prank(owner); 
      string memory actualPassword = passwordStore.getPassword(); 
      assertEq(actualPassword, expectedPassword); 
  }
```
</details>


**Recommended Mitigation:** Add an access control conditional to the `setPassword` function. 

<details>
<summary> expand code </summary>

```javascript 
  if (msg.sender != s_owner) {
    revert PasswordStore_NotOwner(); 
  }
```
</details>

### [I-1] The `PasswordStore::getPassword` natspec indicates there is a param that does not exist, causing the natspec to be incorrect.

**Description:** 
The `PasswordStore::getPassword` function signature is `getPassword()` while the natspec indicates it should be `getPassword(string)`. 

**Impact:** Natspec is incorrect. 

**Recommended Mitigation:** Remove incorrect natspec line. 
```diff 
- @param newPassword The new password to set.
```
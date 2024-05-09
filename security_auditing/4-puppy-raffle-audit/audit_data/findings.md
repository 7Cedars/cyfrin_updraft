Denial of service attack 

### [M-1] An unbound loop at `PuppyRaffle::enterRaffle` creates a possibility for a denial-of-service(DoS) attack, incrementing gas cost for future entrees. 

**Description:** The `PuppyRaffle::enterRaffle` loops through an array of players `players` to check for duplicates. The array `players` is unbound. As the length of `players` increases, the cost to enter the raffle for new players increases as a longer array needs to be checked for duplicates. As a result, early entrants pay little in gas fees, later entrants (much) more. 

```javascript 
// £audit: dos attack 
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
   1. NOTE to self: can insert a diff section so show how this can be done. 
3. 


### [H-1] The `PuppyRaffle::refund` function updates the `players` array _after_ refunding the user. It allows for an external contract to repeatly call the refund function without the array being updated; draining the contract of all funds. It is a classic Reentrancy attack.  

TODO 

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 


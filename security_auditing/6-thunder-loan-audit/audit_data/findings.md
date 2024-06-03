## High
### [H-1] Erroneous `ThunderLoan::updateExchangeRate` in the `deposit` function causes protocol to think it has more fees that is actually the case, that blocks redemptions and incorrectly sets the exchange rate. 

**Description:** In the `ThunderLoan` protocol, the `exchangeRate` is used to calculate the exchange rate between assetTokens and their underlying tokens. Indirectly, it keeps track of how many fees liquidity providers should receive. 

However, the `deposit` function erroneously updates this state - without collecting any fees. 

```javascript 
    function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);

@>        uint256 calculatedFee = getCalculatedFee(token, amount);
@>        assetToken.updateExchangeRate(calculatedFee);

        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

**Impact:** There are several impacts of this bug. 

1. The `redeem` function is potentially blocked because the protocol, bacause it can try to return more tokens than it has. 
2. Rewards are incorrectly calculated, leading to users getting potentially more or less than they deserve. 

**Proof of Concept:**
1. LP depsoits
2. User takes out a flash loan
3. It is now possible for LP to redeem.  

<details>
<summary> Proof of Concept</summary>

Place the following in `ThunderLoanTest.t.sol`

```javascript
     function testRedeemAfterLoan() public  setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);

        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), calculatedFee);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        uint256 amountToRedeem = type(uint256).max ;
        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, amountToRedeem);  
    }
```

</details>

**Recommended Mitigation:** Remove the incorrect update exchange rate lines from `deposit`. 

```diff 
    function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);

-        uint256 calculatedFee = getCalculatedFee(token, amount);
-        assetToken.updateExchangeRate(calculatedFee);

        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

### [H-2] The `ThunderLoan::deposit` function can be called with borrowed money from `ThunderLoan::flashloan`, allowing draining of all funds through taking fees and exchange rate manipulation.

**Description:** 
TO DO 

**Impact:** 
TO DO 

**Proof of Concept:**
TO DO -- see test file. 

**Recommended Mitigation:** 
TO DO 

### [H-3] Mixing up variable location causes storage collision in `ThunderLoan::s_flashLoanFee` and `ThunderLoan::s_currentlyFlashLoaning`, freezing protocol.

**Description:** 
`ThunderLoan.sol` has two storage variables in the following order: 

```javascript
    uint256 private s_feePrecision; 
    uint256 private s_flashLoanFee; 
```

However, `ThunderLoanUpgraded.sol` has them in a different order. 

```javascript
    uint256 private s_flashLoanFee;  
    uint256 public constant FEE_PRECISION = 1e18;
```

Due to how solidity storage works, after the upgrade the `s_flashLoanFee` will have the value of `s_feePrecision`. You cannot adjust the position of storage variables, and removing storage variables for constant variables, also breaks storage location. 

**Impact:** 
After the upgrade the `s_flashLoanFee` will have the value of `s_feePrecision`. As a result, users will pay the wrong fee. Worse, the `s_currentlyFlashLoaning` starts in the wrong stroage slot, breaking the protocol. 

**Proof of Concept:**
1. Initial contract is deployed. 
2. Owner of contract deploys upgrade. 
3. Fee structure breaks.  

<detail> 
<summary> Proof of Concept </summary> 

Place the following in `ThunderLoanTest.t.sol`. 

```javascript
    import { ThunderLoanUpgraded } from  "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";

    function testUpgradesBreaks() public {
        uint256 feeBeforeUpgrade = thunderLoan.getFee(); 
        vm.startPrank(thunderLoan.owner()); 
        ThunderLoanUpgraded upgraded = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(upgraded), ""); 
        uint256 feeAfterUpgrade = thunderLoan.getFee(); 
        vm.stopPrank(); 

        console2.log("fee before upgrade:", feeBeforeUpgrade);  
        console2.log("fee after upgrade:", feeAfterUpgrade); 

        assert(feeBeforeUpgrade != feeAfterUpgrade); 
    }  
```

You can also see the storage difference by running `forge inspect ThunderLoan storage` and `forge inspect ThunderLoanUpgraded storage`. 
</detail>

**Recommended Mitigation:** If you must remove the storage variable, leave it blank to avoid mixing storage slots.  

```diff 
-    uint256 private s_flashLoanFee; 
-    uint256 public constant FEE_PRECISION = 1e18;
+    int256 private s_blank;
+    int256 private s_flashLoanFee;
+    uint256 public constant FEE_PRECISION = 1e18;

```


## Medium 

### [M-1] Using Tswap as price Oracle leads to users getting cheaper borrowing fees. 

**Description:** TODO 

**Impact:** TODO 

**Proof of Concept:** TODO 

**Recommended Mitigation:** Consider using a different price oracle mechanism, like a Chainlink price feed with a Uniswap TWAP fallback oracle. 


## Low 


## Informational 

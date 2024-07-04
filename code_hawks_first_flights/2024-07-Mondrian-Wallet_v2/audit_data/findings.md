## High


**Description:** The [documentation from zksync](https://github.com/zkSync-Community-Hub/zksync-developers/discussions/87) notes that (I added emphasis)
> The block production rate and timestamp refresh time will be gradually increased during the catch up period.
> If your project has critical logics that rely on the values returned from block.number, block.timestamp or blockhash you might face unexpected behaviour (e.g. reduced time for governance voting, spike in rewards etc.). These logics could include (non-exhaustive):
> - [...]
> - Relying on block.number to calculate when an auction ends or **calculate time**.
> - [...]
>  

Additionally, please note that transient storage (and related Opcodes TLOAD and TSTORE) are not supported in zkSync. See the the official documentation: https://www.rollup.codes/zksync-era  Both of these are used in the OpenZeppelin v5 that is imported in `RamNFT.sol`. It does not seem to create an issue at the moment (as ERC721 remains unused in `RamNFT`) but could become a problem as the protocol is adapted prior to deployment.

**Impact:** Currently, and into October, block.timestamp on zkSync cannot be used to calculate time or date. It breaks the core functionality of the contract on this chain.

**Recommended Mitigation:** Either completely change the functionality of the protocol, in order for it not to depend on `block.timestamp` for its functionality, or do not deploy to `zksync`. 

## Medium

## Low 


Just a small note: this was my first first-flight audit. I finished Patrick's Security & Auditing course on Cyfrin updraft last week and approached this first-flight as a kind of exam to that course. 

I am really impressed with how many (different kinds of!) vulnerabilities fit on a really small code base. And I am sure I still did not find all of them. Hats off to Naman Gautam to building this. It was quite a bit of work but a lot of fun. Many thanks!

Have a nice day, 7cedars

## False Positives 

- 
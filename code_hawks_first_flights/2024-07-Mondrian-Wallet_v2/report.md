# Aderyn Analysis Report

This report was generated by [Aderyn](https://github.com/Cyfrin/aderyn), a static analysis tool built by [Cyfrin](https://cyfrin.io), a blockchain security company. This report is not a substitute for manual audit or security review. It should not be relied upon for any purpose other than to assist in the identification of potential security vulnerabilities.
# Table of Contents

- [Summary](#summary)
  - [Files Summary](#files-summary)
  - [Files Details](#files-details)
  - [Issue Summary](#issue-summary)
- [Low Issues](#low-issues)
  - [L-1: `public` functions not used internally could be marked `external`](#l-1-public-functions-not-used-internally-could-be-marked-external)
  - [L-2: Modifiers invoked only once can be shoe-horned into the function](#l-2-modifiers-invoked-only-once-can-be-shoe-horned-into-the-function)
  - [L-3: Empty Block](#l-3-empty-block)
  - [L-4: Unused Custom Error](#l-4-unused-custom-error)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 1 |
| Total nSLOC | 120 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| src/MondrianWallet2.sol | 120 |
| **Total** | **120** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| High | 0 |
| Low | 4 |


# Low Issues

## L-1: `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>1 Found Instances</summary>


- Found in src/MondrianWallet2.sol [Line: 61](src/MondrianWallet2.sol#L61)

	```solidity
	    function initialize() public initializer {
	```

</details>



## L-2: Modifiers invoked only once can be shoe-horned into the function



<details><summary>2 Found Instances</summary>


- Found in src/MondrianWallet2.sol [Line: 47](src/MondrianWallet2.sol#L47)

	```solidity
	    modifier requireFromBootLoader() {
	```

- Found in src/MondrianWallet2.sol [Line: 54](src/MondrianWallet2.sol#L54)

	```solidity
	    modifier requireFromBootLoaderOrOwner() {
	```

</details>



## L-3: Empty Block

Consider removing empty blocks.

<details><summary>2 Found Instances</summary>


- Found in src/MondrianWallet2.sol [Line: 115](src/MondrianWallet2.sol#L115)

	```solidity
	    function prepareForPaymaster(
	```

- Found in src/MondrianWallet2.sol [Line: 169](src/MondrianWallet2.sol#L169)

	```solidity
	    function _authorizeUpgrade(address newImplementation) internal override {}
	```

</details>



## L-4: Unused Custom Error

it is recommended that the definition be removed when custom error is unused

<details><summary>1 Found Instances</summary>


- Found in src/MondrianWallet2.sol [Line: 42](src/MondrianWallet2.sol#L42)

	```solidity
	    error MondrianWallet2__InvalidSignature();
	```

</details>



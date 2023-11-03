// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StatelessFuzzCatches} from "../../src/invariant-break/StatelessFuzzCatches.sol";

contract StatelessFuzzCatchesTest is Test {
    StatelessFuzzCatches public sfc;

    function setUp() public {
        sfc = new StatelessFuzzCatches();
    }

    // // Stateless fuzz
    // // Uncomment this and you'll see it catches the bug!
    // function testFuzzPassesEasyInvariant(uint128 randomNumber) public view {
    //     assert(ibw.doMath(randomNumber) != 0);
    // }
}

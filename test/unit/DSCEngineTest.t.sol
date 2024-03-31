// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";

contract DSCEngineTest is Test {

    DSCEngine dscEngine;
    DecentralisedStableCoin dsCoin;
    DeployDsc deployDsc;


    function setUp() public {
        deployDsc = new DeployDSC();
        //Get and set all our relevant contract addresses that were deployed in the DeployDSC script
        (dsCoin, dscEngine, deployDsc.hc) = deployDsc.run();
    }

    // TODO - add tests!!
    function test_() public {}

    function invariant_() public {}
}

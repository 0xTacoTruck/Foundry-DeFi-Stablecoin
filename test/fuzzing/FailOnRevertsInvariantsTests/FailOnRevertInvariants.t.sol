// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";

import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../../src/DecentralisedStableCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FailOnRevertHandler} from "../FailOnRevertsInvariantsTests/FailOnRevertHandler.t.sol";

//Invariants test file will have our invariants AKA our proprties of our code that should always hold

/**
    * WHAT ARE THE INVARAINTS OF OUR PROJECT?
    *
    * 1. Total supply of DSC should be less in value than the total value of collateral
    * 2. Getter view functions hould never revert <-- evergreen invariant
    * There are mroe but we will focus on these for now

    * THIS STATEFUL FUZZING TEST FILE WILL USE HANDLERS FROM Handler.t.sol
*/
contract InvariantsTest is StdInvariant, Test {

    FailOnRevertHandler handler;

    DSCEngine dscEngine;
    DecentralisedStableCoin dsCoin;
    DeployDSC deployDsc;

    HelperConfig hc;

    // Active Network Config Variables - We don't need all of them right now
    address wethUSDPriceFeed;
    address wbtcUSDPriceFeed;
    address wethToken;
    address wbtcToken;
    uint256 deployerKey;

    


    /*//////////////////////////////////////////////////////////////
                                Set Up
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        deployDsc = new DeployDSC();

        //Get and set all our relevant contract addresses that were deployed in the DeployDSC script
        (dsCoin, dscEngine, hc) = deployDsc.run();


        (wethUSDPriceFeed, wbtcUSDPriceFeed, wethToken, wbtcToken, deployerKey) = hc.activeNetworkConfig();
        
        //TargetContract tells foundry what contract to randomlly call functions of and pass random values to - We are going to pass our engine contract
        //targetContract(address(dscEngine));

        //We can also set the Handler as the target contract to focus Foundry to use and go through
        // Handler can be useful for steering our tests in a meaningful way - like don't call redeemCollateral unless there is collateral to be redeemed
        handler = new FailOnRevertHandler(dscEngine,dsCoin);
        targetContract(address(handler));
    }



    /*//////////////////////////////////////////////////////////////
                   Invaraints - Stateful Fuzz Tests
    //////////////////////////////////////////////////////////////*/

    // @note THAT THIS INVARAINT TEST WILL FAIL IF THERE IS ZERO COLLATERAL AND ZERO DSC MINTED BECAUSE TOTAL COLLATERAL IS WORTH THE SAME AS ZERO TOKENS MINTED
    // For testing purposes only to understand these fuzz tests, we can modify the '>' to '>=' in our assert
    function invariant_protocolMustHaveMoreCollateralValueThanTotalSupply() public{
        // Get the value of ALL collateral in protocl
        // Compare it to the total supply of DSC

        //We knwo the only way for people to mint tokens is through the DSC contract
        uint256 totalSupply = dsCoin.totalSupply();
        
        //Get total collateral value of each token by using the ERC(IERC20) interface of each token - where we got the address of each token from our helper cofnig
        uint256 totalWETHDeposited = IERC20(wethToken).balanceOf(address(dscEngine));
        uint256 totalWBTCDeposited = IERC20(wbtcToken).balanceOf(address(dscEngine));

        //Calculate the value of each token
        uint256 totalWETHValue = dscEngine.getUsdValueOfToken(wethToken, totalWETHDeposited);
        uint256 totalWBTCValue = dscEngine.getUsdValueOfToken(wbtcToken, totalWBTCDeposited);

        console.log("totalWETHValue: ", totalWETHValue);
        console.log("totalWBTCValue: ", totalWBTCValue);
        console.log("totalSupply: ", totalSupply);
        console.log("Times Mint Function Executed from Handler: ", handler.timesMintFunctionCalled());

        // Assert that the collateral value is more than the amount of tokens minted
        //CHANGE '>=' TO '>'ONCE EVERYTHING SET UP
        assert(totalWETHValue + totalWBTCValue >= totalSupply);
    }


    /*//////////////////////////////////////////////////////////////
                      Getter Function Invariant
    //////////////////////////////////////////////////////////////*/

    //Getter functions should never revert and if any combination of function calls in Handler break this, then we have a problem and we have broken our invariant
    //The are lay-up invaraint tests that every single project should do
    function invariant_getterFunctionsShouldNeverRevert() public view{
        dscEngine.getAdditionalPriceFeedPrecision();
        dscEngine.getApprovedCollateralTokens();
        dscEngine.getLiquidationBonus();
        dscEngine.getDSCAddress();
        dscEngine.getMinHealthFactor();
        dscEngine.getLiquidationThreshold();
        dscEngine.getPrecision();
    }
        




}
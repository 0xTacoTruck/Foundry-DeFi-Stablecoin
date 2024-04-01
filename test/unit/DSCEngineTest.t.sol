// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {

    DSCEngine dscEngine;
    DecentralisedStableCoin dsCoin;
    DeployDSC deployDsc;

    HelperConfig hc;

    // Active Network Config Variables
    address wethUSDPriceFeed;
    address wbtcUSDPriceFeed;
    address wethToken;
    address wbtcToken;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 15 ether;
    uint256 public constant APPROVED_COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_TOKENS_BALANCE = 10 ether;
    


    function setUp() public {

        deployDsc = new DeployDSC();
        
        //Get and set all our relevant contract addresses that were deployed in the DeployDSC script
        (dsCoin, dscEngine, hc) = deployDsc.run();
        

        (wethUSDPriceFeed, wbtcUSDPriceFeed, wethToken, wbtcToken,deployerKey) = hc.activeNetworkConfig();

        vm.deal(USER, STARTING_USER_BALANCE);
        //Mint some tokens to user
        ERC20Mock(wethToken).mint(USER, STARTING_ERC20_TOKENS_BALANCE);
        ERC20Mock(wbtcToken).mint(USER, STARTING_ERC20_TOKENS_BALANCE);
    }




    ///////////////////
    // Price Tests   //
    ///////////////////

    function testGetUsdValueOfToken() public {

        //15e18 = 15 ETH in WEI
        uint256 ethAmount = 15e18;
        // 15e8 ETH * $2000 USD/ETH (helperconfig) = $30,000e18 USD
        // WE SET THE INITAL PRICE TO BE RETURNED BY THE AGGREGATOR WHEN USING THE MOCK AGGREGATORV3 - WHICH IS DEPLOYED ON ANVIL. MEANING WE KNOW THE PRICE
        uint256 expectedUSD = 30000e18;
        assert(dscEngine.getUsdValueOfToken(wethToken,ethAmount) == expectedUSD); //WEI

        uint256 btcAmount = 12e18;
        // 12e18 BTC * $1000 USD/BTC (helperconfig) = $12,000e18 USD
        // WE SET THE INITAL PRICE TO BE RETURNED BY THE AGGREGATOR WHEN USING THE MOCK AGGREGATORV3 - WHICH IS DEPLOYED ON ANVIL. MEANING WE KNOW THE PRICE
        expectedUSD = 12000e18;
        assert(dscEngine.getUsdValueOfToken(wbtcToken,btcAmount) == expectedUSD); //WEI
    }


    ///////////////////////////////
    // Deposit Collateral Tests  //
    ///////////////////////////////

    function testDepositCollateralRevertsWithZeroCollateralAmount() public {
       
        vm.startPrank(USER);
        
        //Set the DSC Enginge Contract as an approved user on our behalf for ERC20 token transfers up to the provided amount
        ERC20Mock(wethToken).approve(address(dscEngine), APPROVED_COLLATERAL_AMOUNT);

        //Specific revert error we are expecting
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);

        dscEngine.depositCollateral(wethToken, 0);

        vm.stopPrank();
    }
}

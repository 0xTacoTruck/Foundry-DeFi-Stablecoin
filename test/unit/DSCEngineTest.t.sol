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
    uint256 public constant APPROVED_COLLATERAL_AMOUNT = 20 ether;
    uint256 public constant STARTING_ERC20_TOKENS_BALANCE = 10 ether;

    function setUp() public {
        deployDsc = new DeployDSC();

        //Get and set all our relevant contract addresses that were deployed in the DeployDSC script
        (dsCoin, dscEngine, hc) = deployDsc.run();

        (wethUSDPriceFeed, wbtcUSDPriceFeed, wethToken, wbtcToken, deployerKey) = hc.activeNetworkConfig();

        vm.deal(USER, STARTING_USER_BALANCE);
        //Mint some tokens to user
        ERC20Mock(wethToken).mint(USER, STARTING_ERC20_TOKENS_BALANCE);
        ERC20Mock(wbtcToken).mint(USER, STARTING_ERC20_TOKENS_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                             Price Tests
    //////////////////////////////////////////////////////////////*/

    function testGetUsdValueOfToken() public {
        //15e18 = 15 ETH in WEI
        uint256 ethAmount = 15e18;
        // 15e8 ETH * $2000 USD/ETH (helperconfig) = $30,000e18 USD
        // WE SET THE INITAL PRICE TO BE RETURNED BY THE AGGREGATOR WHEN USING THE MOCK AGGREGATORV3 - WHICH IS DEPLOYED ON ANVIL. MEANING WE KNOW THE PRICE
        uint256 expectedUSD = 30000e18;
        assert(dscEngine.getUsdValueOfToken(wethToken, ethAmount) == expectedUSD); //WEI

        uint256 btcAmount = 12e18;
        // 12e18 BTC * $1000 USD/BTC (helperconfig) = $12,000e18 USD
        // WE SET THE INITAL PRICE TO BE RETURNED BY THE AGGREGATOR WHEN USING THE MOCK AGGREGATORV3 - WHICH IS DEPLOYED ON ANVIL. MEANING WE KNOW THE PRICE
        expectedUSD = 12000e18;
        assert(dscEngine.getUsdValueOfToken(wbtcToken, btcAmount) == expectedUSD); //WEI
    }

    function testGetTokenAmountFromUSD() public {
        uint256 UsdAmountOfToken = 100 ether;
        //$2000/1 ETH  100e18 WEI/? ETH --> 100e18 WEI / $2000 = 50,000,000,000,000,000 == 0.050000000000000000 == 0.05e18 of collateral
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUSD(wethToken, UsdAmountOfToken);
        assertEq(actualWeth, expectedWeth);
    }

    /*//////////////////////////////////////////////////////////////
                       Deposit Collateral Tests
    //////////////////////////////////////////////////////////////*/

    function testDepositCollateralRevertsWithZeroCollateralAmount() public {
        vm.startPrank(USER);

        //Set the DSC Enginge Contract as an approved user on our behalf for ERC20 token transfers up to the provided amount
        ERC20Mock(wethToken).approve(address(dscEngine), APPROVED_COLLATERAL_AMOUNT);

        //Specific revert error we are expecting
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);

        dscEngine.depositCollateral(wethToken, 0);

        vm.stopPrank();
    }

    function testDepositCollateralRevertsWithNonApprovedToken() public {
        uint256 wethAmount = 1 ether;
        ERC20Mock ranToken =new ERC20Mock("FunToken","FUN",address(USER),STARTING_ERC20_TOKENS_BALANCE);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenIsNotAllowed.selector);
        dscEngine.depositCollateral(address(ranToken), wethAmount);
    }


    function testDepositCollateralFailsToTransferTokensToDSCEngineBecauseInsufficientBalance() public {
        uint256 wethAmount = 19 ether; //More than balance of user
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.depositCollateral(wethToken, wethAmount);
    }

     function testDepositCollateralFailsToTransferTokensToDSCEngineBecauseInsufficientAllowance() public {
        uint256 wethAmount = 100 ether; //More than balance of user
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.depositCollateral(wethToken, wethAmount);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedWETHCollateral{
       (uint256 totalDSCMinted, uint256 totalCollateralValueUSD) = dscEngine.getAccountInfo(USER);
       //Was just deposit call, not minting - so should be zero
       uint256 expectedDSCMinted = 0;
       assertEq(totalDSCMinted, expectedDSCMinted);
       
       //Only deposited 1 token of collateral, total collateral should equal the deposited amount of token based upon USD value of total collateral value
       uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUSD(wethToken, totalCollateralValueUSD);
       assertEq(10 ether, expectedDepositAmount);

       //Total collateral value should equal the USD value of the deposited amount of WETH token which is 1 ether, because the deposit modifier only deposits 1 token
       uint256 expectedCollateralValueUSD = dscEngine.getUsdValueOfToken(wethToken, 10 ether);
       assertEq(totalCollateralValueUSD, expectedCollateralValueUSD);

       
    }

    

    function testCanDepositCollateralWithoutMinting() public depositedWETHCollateral {
        uint256 userBalance = dsCoin.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                 Deposit Collateral & Mint DSC Tests
    //////////////////////////////////////////////////////////////*/


    function testDepositCollateralAndMintDSCAndGetAccountInfo() public  {
        //amount to mint 40 DSC to USER
        uint256 amountDscToMint = 40e16;
        //deposit amount of 1 ETH
        uint256 amountCollateral = 1 ether;
        //Approve the engine to transfer our funds/tokens to it
        vm.startPrank(USER);
        ERC20Mock(wethToken).approve(address(dscEngine), APPROVED_COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDSC(wethToken, amountCollateral, amountDscToMint);
        vm.stopPrank();

        //Get and verify account info
        (uint256 totalDSCMinted, uint256 totalCollateralValueUSD) = dscEngine.getAccountInfo(USER);

        assertEq(amountDscToMint, totalDSCMinted);

        //Only deposited 1 token of collateral, total collateral should equal the deposited amount of token based upon USD value of total collateral value
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUSD(wethToken, totalCollateralValueUSD);
        assertEq(1 ether, expectedDepositAmount);

        //Total collateral value should equal the USD value of the deposited amount of WETH token which is 1 ether, because the deposit modifier only deposits 1 token
        uint256 expectedCollateralValueUSD = dscEngine.getUsdValueOfToken(wethToken, 1 ether);
        assertEq(totalCollateralValueUSD, expectedCollateralValueUSD);
    }

    /*//////////////////////////////////////////////////////////////
                          Constructor Tests
    //////////////////////////////////////////////////////////////*/

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testDSCEngineRevertsWhenTokenLengthDoesntMatchPriceFeedLength() public {
        tokenAddresses.push(wethToken);
        tokenAddresses.push(wbtcToken);

        //Will only push 1 price feed address to test constructor revert
        priceFeedAddresses.push(wethUSDPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsCoin));
    }


    /*//////////////////////////////////////////////////////////////
                              Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier depositedWETHCollateral() {
        uint256 depositAmount = 10 ether;
        vm.startPrank(USER);
        //Approve the engine to transfer our funds/tokens to it
        ERC20Mock(wethToken).approve(address(dscEngine), APPROVED_COLLATERAL_AMOUNT);

        dscEngine.depositCollateral(wethToken, depositAmount);

        vm.stopPrank();
        _;
    }

   


    /*//////////////////////////////////////////////////////////////
                            Minting DSC Tests
    //////////////////////////////////////////////////////////////*/

   

    function testCanMintDSCWhenCollateralDoesNotExceedMaxCollateralizationRate() public depositedWETHCollateral() {
        uint256 amountDscToMint = 100000 * (10 ** 18);
        //Should be able to mint 100,000 DSC
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.mintDSC(amountDscToMint);
    }

    function testCannotMintDSCWhenCollateralExceedsMaxCollateralizationRate() public depositedWETHCollateral() {
        uint256 amountDscToMint = 200000 * (10 ** 18);
        //Should not be able to mint 200,000 DSC
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.mintDSC(amountDscToMint);
    }

    function testMintDSC() public depositedWETHCollateral() {
        uint256 amountDscToMint = 1e16;
        uint256 userBalanceBefore = dsCoin.balanceOf(USER);
        vm.prank(USER);
        dscEngine.mintDSC(amountDscToMint);
        uint256 userBalanceAfter = dsCoin.balanceOf(USER);

        assertEq(userBalanceAfter, userBalanceBefore + amountDscToMint);
    }

     function testMintDSCFailsForHealthFactor() public depositedWETHCollateral() {
        uint256 amountDscToMint = 100000 * (10 ** 18);
        vm.expectRevert();
        dscEngine.mintDSC(amountDscToMint);
        
    }

    
}

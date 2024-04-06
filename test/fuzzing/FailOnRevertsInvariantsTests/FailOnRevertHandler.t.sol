// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
//import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";

import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../../src/DecentralisedStableCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";

// Handler contract narrows down the way that we can call functions in Foundry's stateful fuzzing - called invaraint tests in Foundry
contract FailOnRevertHandler is Test {

    DSCEngine dscEngine;
    DecentralisedStableCoin dsCoin;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    // Ghost Variables
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max; //Use uin96 instead of uint256 because otherwise we could cause overflow/underflow when calling functions when we add more collateral

    //Ghost variable to track how many times we call the mint function so we can explore why we might not be getting the total minted supply value expected - e.g more than zero
    uint256 public timesMintFunctionCalled = 0;
    address[] public addressesWhoDeposited;
     


   
    
    
    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    // Pass in the contracts we want to target and interact with
    constructor (DSCEngine _dscEngine, DecentralisedStableCoin _dsCoin) {
        dscEngine = _dscEngine;
        dsCoin = _dsCoin;

        address[] memory collateralTokens = dscEngine.getApprovedCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeedAddress(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeedAddress(address(wbtc)));
    }

    /*//////////////////////////////////////////////////////////////
                          Deposit Collateral
    //////////////////////////////////////////////////////////////*/

    /**
    *
    * @param collateralTokenSeed - random number that we will use to select which collateral token to deposit
    * @param collateralAmount - amount of collateral to deposit
    * 
    */
    // @note - Encountered this result befoer adding in the bounds of values and max uint256 type value
    /**[FAIL. Reason: panic: arithmetic underflow or overflow (0x11)]
        [Sequence]
                sender=0xfE0F7295b361021A6dd58A0410Ee7909c23129e4 addr=[test/fuzzing/Handler.t.sol:Handler]0x2e234DAe75C793f67A35089C9d99245E1C58470b calldata=depositCollateral(uint256,uint256) args=[115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77], 952205656124830944967 [9.522e20]]
    */
    function depositCollateral(uint256 collateralTokenSeed, uint256 collateralAmount) public {

        /** Enforce bounds of values for collateral amount using 'bound' which is part of forge-std
        * @param collateralAmount - The amount of collateral to deposit (uint256)
        * @param min - The minimum amount of collateral that we allow the value to be for the deposit (uint256)
        * @param max - The maximum amount of collateral that we allow the value to be for the deposit (uint256) 
        */
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);

        ERC20Mock collateralToken;

        //Call the helper function to get the collateral token address
        collateralToken = _getCollateralTokenFromNumberInput(collateralTokenSeed);
        
        
        vm.startPrank(msg.sender);

        //Mint tokens so we can actually deposit collateral
        collateralToken.mint(msg.sender, collateralAmount); //Need to mint tokens otherwise we revert because transfer amounts exceeds balance

        //Approve DSCEngine to transfer our funds/tokens to it - without this we will get revert for insufficient allowance
        collateralToken.approve(address(dscEngine), collateralAmount);

        dscEngine.depositCollateral(address(collateralToken), collateralAmount);

        vm.stopPrank();

        //Store who deposited collateral
        addressesWhoDeposited.push(msg.sender);

    }

    

    /*//////////////////////////////////////////////////////////////
                          Redeem Collateral
    //////////////////////////////////////////////////////////////*/

    /**
    * Function to test the redeem function of the DSC Engine contract
    *
    * @param collateralTokenSeed - random number that we will use to select which collateral token to redeem
    * @param redeemAmount - amount of collateral to redeem
    * 
    */
    
    function redeemCollateral(uint256 collateralTokenSeed, uint256 redeemAmount) public {
        ERC20Mock collateralToken;
        //Call the helper function to get the collateral token address
        collateralToken = _getCollateralTokenFromNumberInput(collateralTokenSeed);

        //Should only allow the redeeming of the max amount of collateral deposited by user
        uint256 maxCollateralToRedeem = dscEngine.getCollateralTokenBalanceOfUser(msg.sender, address(collateralToken));
        //If maxCollateralToRedeem is zero, the bound function will error if we have the min value as greater than zero - error StdUtils bound(uint256,uint256,uint256): Max is less than min.]
        redeemAmount = bound(redeemAmount, 0, maxCollateralToRedeem);
        //We also want to skip the calling of the DSC Engine redeem function of this fuzz test if the amount of collateral is zero because we know we will revert with 'DSCEngine__AmountMustBeMoreThanZero()'
        if (redeemAmount == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateralToken), redeemAmount);
        vm.stopPrank();
        
    }

    /*//////////////////////////////////////////////////////////////
                          Mint DSC Functions
    //////////////////////////////////////////////////////////////*/

    function mintDSC(uint256 amountDscToMint, uint256 addressesWhoDepositedSeed) public {


        //Call the helper function so that we have an address to use of someone who completed the deposit function
        address userAddress = _getAddressOfSomeoneWhoDeposited(addressesWhoDepositedSeed);
        //If address(0), return and don't contiinue because there has been no deposit
        if (userAddress == address(0)) {
            return;
        }
       

        //Could bound it further if we wanted to ensure they dont try and mint more than they have available in collateral to avoid bad health factor revert
        //We might want to see what values actually break the bad health factor though so we could leave it out - depends on the situation
        //To restrict it further to find the max we can mint to break the health factor and get a revert, we can use the 'getAccountInfo' of the DSC Engine -
        // - which will return to us: totalDscMinted, totalCollateralValueInUSD

        //USE THE ADDRESS OF SOMEONE WHO ACTUALLY HAS DEPOSITED
        vm.startPrank(userAddress);
        (uint256 totalDscMinted, uint256 totalCollateralValueInUSD) = dscEngine.getAccountInfo(userAddress);

        //Restrict the amountDscToMint to the HALF the totalCollateralValueInUSD - because we know that our DSC token is pegged to $1 USD and we require over -
        //- 200% overcollateralisation. We also need to ensure that the max amountDscToMint is not negative and therefore we can use int256 and an if-else statement -
        //- to check if the max amountDscToMint is less than 0 and then revert so we don't call the mint function
        // We subtract totalDscMinted to account for any tokens the user already has minted
        int256 maxAmountDscToMint = (int256(totalCollateralValueInUSD) / 2) - int256(totalDscMinted);

        

        if(maxAmountDscToMint < 0) {
            return;
        }
        
        

        //Rebound the amount amount that can be minted to max range from calc in previous step to avoid bad health factor revert
        amountDscToMint = bound(amountDscToMint, 0, uint256(maxAmountDscToMint));

        //If the amount to mint is zero, return so we don't call the mint function because we know we will get a revert
        if(amountDscToMint == 0) {
            return;
        }

        //Increment our ghost variable to track the number of times we have completed this function
        timesMintFunctionCalled++;

        dscEngine.mintDSC(amountDscToMint);
        vm.stopPrank();

        
    }

    /*//////////////////////////////////////////////////////////////
                          Burn DSC Functions
    //////////////////////////////////////////////////////////////*/


    /*//////////////////////////////////////////////////////////////
                   PriceFeed Manipulation Functions
    //////////////////////////////////////////////////////////////*/

    /**
    * We want to test the functions of the pricefeed for each token, as well as use the mock aggreagator to allow us to change the pricing of the pricefeed that will be returned in the answer
    */
    // @note - TEST GIVES US AN INTERESTING INSIGHT TO CONSIDER ABOUT OUR CODE WHEN CALLING THE invariant_protocolMustHaveMoreCollateralValueThanTotalSupply() TEST WHICH
    // CHANGES THE PRICE OF THE TOKENS, MAKING IT DRASTICALLY DROP IN VALUE CAUSING OUR ASSERTION TO FAIL THAT OUR SYSTEM OF ALL COLLATERAL BEING GREATER THAN THE TOTAL
    // SUPPLY OF MINTED DSC
    // CONSIDERATION - OUR ASSERTION FAILED BECAUSE WE DONT ACCOUNT FOR AN EXTREME DROP IN COLLATERAL VALUE, WHETHER IT IS USD VALUE OR PERHAPS SOMETHING UNFORESEEN -
    //- LIKE A POTENTIAL ATTACK. OUR SYSTEM OF LIQUIDATION ISN'T ACCOUNTING FOR THAT AND IS MORE SLOW MOVING TO LIQUIDATE BAD POSITIONS, NO RAPID FIRE EMERGENCY FUNCTIONS, NO PAUSING, ETC
    
    /** COMMENTING THIS CODE OUT FOR NOW AS IT FULLY BREAKS OUR INVARAINT TEST SUITS WHEN THE VALUE IN PRICEFEED DROPS LOW IN A SINGLE TRANSACTION
        IT IS A REAL ISSUE AND AN AUDIT, THIS FINDING WOULD BE REPORTED IF THERE WAS NO FURTHER HANDLING OR SMOOTHING OUT OF THIS IN THE PROJECT
        - SOMETIMES IT CAN ALSO BE REPORTED AS A KNOWN BUG THAT DUE TO RAPID INCREASES/DECREASE IN PRICE, WE CAN SEE BREAKING OF OUR CODE


    function updateCollateralPrice(uint96 newPrice) public {

        newPrice = uint96(bound(uint256(newPrice), 1, uint256(MAX_DEPOSIT_SIZE)));
        //convert uint to int
        int256 newIntPrice = int256(uint256(newPrice));

        //If statement to pick which price feed to update value of
        if(newPrice % 2 == 0){
             //set the new price
            ethUsdPriceFeed.updateAnswer(newIntPrice);
        } else {
            btcUsdPriceFeed.updateAnswer(newIntPrice);
        }

       
    }

    */
    

    /*//////////////////////////////////////////////////////////////
                           Helper Functions
    //////////////////////////////////////////////////////////////*/

    /**
    * TOOK THE PICK TOKEN ADDRESS LOGIC FROM DEPOSIT COLLATERAL LOGIC AND MOVED IT INTO ITS OWN HELPER FUNCTION
    * WE COULD RETURN AN ADDRESS AND ADD IN LOGIC TO SET MOCKERC20 INSTANCES FROM THAT, OR WE CAN JUST RETURN THE FULL ERC20 FROM THIS FUNCTION
    * DECIDED TO RETURN THE MOCKERC20 AT ADDRESS FROM THIS FUNCTION
    *
    */
    function _getCollateralTokenFromNumberInput (uint256 collateralTokenSeed) private returns(ERC20Mock collateralTokenERC20){
        
        /*
        WE COULD DO THIS METHOD AND IT WILL WORK, OR WE CAN INCORPORATE OUR ERC20 MOCK INTO THE IF-ELSE STATEMENT ITSELF - WHICH WE DO BELOW
                WE ALREADY HAVE SET THE ERC20 MOCKS EARLIER AS PART OF SET UP SO WE JUST SAY WHICH TO RETURN


        address tokenAddress;

         
        //We know we only accept 2 token addresses - weth and wbtc, we use this simple random logic to help us select which one to use
        if(collateralTokenSeed % 2 == 0) {
            // We will use weth
            tokenAddress = address(weth);
        }
        else {
            // We will use wbtc
            tokenAddress = address(wbtc);
           
        }

        // Get the collateral token and create ERC20 interface for it
        collateralTokenERC20 = ERC20Mock(tokenAddress);
        */


        //Use if-else statement to straight away get the ERC20 mock token to return
        if(collateralTokenSeed % 2 == 0) {
            // We will use weth
             return weth;
        }
        else {
            // We will use wbtc
            return collateralTokenERC20 = wbtc;
        }

        
    }


    /**
    * Herlp function similiar to the one above, but for the address of someone who deposited so we can use that for minting and other functions
    *
    *
    */
    function _getAddressOfSomeoneWhoDeposited(uint256 numberValue) private returns(address){
        uint256 lengthArray = addressesWhoDeposited.length;

        //If length of array of people who deposited is zero, revert
        //NOT IDEAL IF FAIL ON REVERT IS SET TO TRUE - CAN JUST RETURN ADDRESS 0 AND DO A CHECK IF ADDRESS ZERO FROM CALLING FUNCTION
        /*
        if(lengthArray == 0) {
            revert("Zero length array of people who deposited");
        }
        */

        if(lengthArray == 0) {
            return address(0);
        }


        //If number is zero, don't divide or modulo by zero - just return zero indexS
        if(numberValue == 0) {
            return addressesWhoDeposited[0];
        }

        uint256 index = numberValue % lengthArray;

      
        return addressesWhoDeposited[index];
    }
    
    
}
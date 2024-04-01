// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/* CONTRACT REQUIREMENTS AND FUNCTIONS:
 * - Deposit collateral and mint Decentralised Stable Coin (DSC)
 * - Redeem collateral for DSC
 * - Burn DSC - allow users to quickly burn some DSC for that amount in collateral
 * - Liquidate - a function that allows the removal of people in positions whose collateral value threatens the stability of the DSC. This requires setting some thresholds.
 * - Get Health factor - external view - allows us to see how healthy of a positions people have
 * - Deposit collateral
 * - Redeem collateral
 * - Mint DSC
 */

/*Rule of thumb: Whenever make a storage update, we should emit an event
        2 main reasons for events:
            1. Makes mitigation/updating easier
            2. Makes front end 'indexing' easier
*/

pragma solidity ^0.8.19;

/**
 * @title DSCEngine
 * @author TheUser1935
 *
 * The system is designed to be as minimal as possible for learning purposes.
 * It is designed to maintain the valuation of the Decentralised Stable Coin value to be pegged to 1 USD (1 token == $1 USD).
 * This stablecoin has the properties:
 * Collateral: Exogenous (ETH (wETH), BTC (wBTC))
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * It is simliar to DAI, if Dai had no fees, no governance and was only backed by wETH and wBTC
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSC, as well depositing and withdrawing collateral.
 *
 * @notice This contract is VERY looseley based on the MakerDAO DSS (DAI) system
 *
 * @dev Function statement order - CEI:
 *          1. Checks
 *          2. Effects - on own contract/state
 *          3. Interactions - interactions with other contracts
 */
import {DecentralisedStableCoin} from "./DecentralisedStableCoin.sol";

// Open Zeppelin have a Non-Reentrant modifier that we can use to help protect against reentrancy. It sits in the ReentrancyGuard abstract contract
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Allows us to use transfer functions already written in accorance with the standards
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Import Aggregator V3 Interface so we can get pricefeeds
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    ////////////////////////
    // State Variables    //
    ////////////////////////

    // @note - Could do this, but because we will be using pricefeeds in this project. We can actually use the pricefeed addresses that are relevant to us
    //mapping(address => bool) private s_tokenToAllowed
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPricefeed

    //Need to track how much collateral a user has actually deposited
    // Map the address of the user to another mapping of token to amount
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; //userToCollateralAmount

    //Map user to amount of DSC user has (Remember DSC is essentially their debt amount)
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;

    //Array of allowed collateral token addresses
    address[] private s_tokenAddresses;

    //immutable variable for the Decentralised Stablecoin Contract to allow us to call its functions and stuff
    DecentralisedStableCoin private immutable i_dsc;

    //Constant variable for the number of decimals different between WEI and returned value from chainlink pricefeeds
    uint256 private constant ADDITIONAL_PRICEFEED_PRECISION = 1e10;

    //Constant variable for the number of decimals to divide our USD price of a token by so that it is more readable and useful. Also used health checks, allowing us to standardise and compare numbers.
    uint256 private constant PRECISION = 1e18;

    //----------------- LIQUIDATION THRESHOLDS, PRECISIONS, HEALTH VALUES ---------------------

    //Liquidation threshold - used to determine when to liquidate a user so that we always remain overcollateralised. VIEW LIKE 50 OUT OF 100, OR 50%. ALLOWS USERS TOTAL COLLATERAL TO DROP BY 50% BEFORE LIQUIDATION
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // means you need to be 200% overcollateralised

    //Liquidiation precision - VIEW LIKE 100%, OR 100 OUR OF 100. ITS THE RATIO PERCENTAGE MINIMUM THAT WE REQUIRE. THE HIGHER THE VALUE, THE STRICTER AND MORE RISK ADVERSE THE SYSTEM IS
    uint256 private constant LIQUIDATION_PRECISION = 100;

    //Minimum health factor score to determine if a user holds a healthy position or if they are to be liquidated.
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    // The Liquidation bonus for users that liquidate bad positioned users. To reward them for protecting stability of protocol.
    uint256 private constant LIQUIDATION_BONUS = 10; // This means 10% bonus



    ////////////////////
    // Errors         //
    ////////////////////
    error DSCEngine__AmountMustBeMoreThanZero();

    error DSCEngine__CollateralTokenIsNotAllowed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
    error DSCEngine__StableCoinAddressMustNotBeZero();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOK();

    ////////////////////
    // Events         //
    ////////////////////

    //Remember Events can have up to 3 indexed parameters - indexed parameters AKA Topics
    //Indexed Params are searchable by topic
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event DSCMinted(address indexed user, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    ////////////////////
    // Modifiers     //
    ////////////////////

    // modifier to not allow 0 as an amount
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }

        _;
    }

    // Modifier to ensure collateral token address is in our list of allowed collateral. If token not allowed, revert
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__CollateralTokenIsNotAllowed();
        }

        _;
    }

    ////////////////////
    // Functions      //
    ////////////////////

    /**
     * We want to pass in an array of allowed token addresses to the constructor so that we can use it in the isAllowedToken modifier and for associated pricefeeds that we also need to pass in.
     * We also need to make sure our engine has the address of our token - Decentralised Stable Coin.
     *
     * @param tokenAddresses - an array of allowed token addresses
     * @param priceFeedAddresses - an array of pricefeed addresses. Will use USD pricefeeds since our stablecoin is pegged to USD
     * @param DscAddress - the address of the Decentralised Stable Coin
     * 
     * @dev ---> BELOW */
    // @note The DSC ERC20 contract is Ownable, the Ownnable contract requires the address of the contract owner as a parameter. Since we deploy the token before deploying the engine, msg.sender is the orignal owner but as part of constructor we should call the change owner function?? NOT 100% CERTAIN
    
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DscAddress) {
        // Make sure that there is the same number of tokens and pricefeeds passed in
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
        }

        //Make sure we have an address passed in
        if (DscAddress == address(0)) {
            revert DSCEngine__StableCoinAddressMustNotBeZero();
        }

        // Update pricefeeds mapping and also store our token addresses to array
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_tokenAddresses.push(tokenAddresses[i]);
        }

        i_dsc = DecentralisedStableCoin(DscAddress);
    }

    /////////////////////////////////
    // Public & External Functions //
    /////////////////////////////////

    /**
     * We need to know what collateral they want to deposit, done by passing in the address of the collateral they want, plus we want the amount of collateral they want to deposit
     * @param tokenCollateralAddress - the address of the collateral token to deposit
     * @param amountCollateral - the amount of collateral to deposit
     * @dev we don't want to allow anyone to deposit nothing, so use of modifier to not allow 0 as an amount
     * @dev we only want collateral tokens that are allowed by our project
     *
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral) // Amount must be more than 0
        isAllowedToken(tokenCollateralAddress) // Is the collateral token allowed
        nonReentrant // Non-Reentrant modifier to prevent re-entrancy attacks
    {
        // Deposit collateral and update amount of collateral deposited for the user
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        // Emit the deposited collateral event since we updated storage variable
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // Transfer collateral from user to our contract
        // @note - relies on the tokenCollateralAddress inheriting from IERC20 interface
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        // Revert if not successful
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }



    /**
    * This external function is used to deposit collateral, and the mint a specified amount of our DSC token. We check that non-zero values are passed in to the function
    * @param tokenCollateralAddress - the address of the collateral token to deposit
    * @param amountCollateral - the amount of collateral to deposit
    * @param amountDscToMint - the amount of DSC to mint
    *
    */
    function depositCollateralAndMintDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint)
        external
        moreThanZero(amountCollateral)
        moreThanZero(amountDscToMint)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        depositCollateral(tokenCollateralAddress, amountCollateral);

        mintDSC(amountDscToMint);

    }



    /**
    * In order to redeem (withdraw) collateral, need to:
    * 1. Update the amount of total collateral deposited by user
    * 2. Emit event since we modified state. 
    * 3. Attempt to transfer collateral to user - Revert transaction if failure
    * 4. Check Health of user's position so we don't jeopardise our overcollateral protection and thresholds - require health factor of 1 AFTER collateral pulled
    * 5. Revert if health check fails
    */
    //@note - This as a stand-alone withdraw function is incomplete, if a user has deposited $100 ETH and only minted $20 of DSC, but they try and withdraw all of it - the function will break. We don't handle any burning of DSC in this function. We need a burn function for users DSC, and we probably need a function to handle both burning and redeeming.
    /** @param tokenCollateralAddress - the address of the collateral token to withdraw
    * @param amountCollateral - the amount of collateral to withdraw
    *
    */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public isAllowedToken(tokenCollateralAddress) moreThanZero(amountCollateral) nonReentrant {
        // Update the amount of collateral use has of the specified token. Was thinking about adding checks in that the amount requested is less than the amount wanting to be withdraw, however, Patrick explains in the video that in these newer versions of solidity, this is not possible and it will revert.
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;

        //Updated state, emit event
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);

        // Normal thinking sugges to perform health check here, but this is quite gas inefficient. We can do the token trasnfer to user and then do health check because we will still revert the transaction if the health check fails
        (bool success) = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        // Revert transaction if health check fails after updating collateral value of user
        _revertIfHealthFactorIsBroken(msg.sender);
    }




    /**
    * This function allows the user to redeem their collateral and burn DSC in one transaction.
    * It will call our exisitng redeemCollateral & burnDSC functions
    *
    * Makes use of our modifers: moreThanZero, isAllowedToken, nonReentrant
    * @param tokenCollateralAddress - the address of the collateral token to deposit
    * @param amountCollateral - the amount of collateral to deposit
    * @param amountDscToBurn - the amount of DSC to burn
    */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external nonReentrant isAllowedToken(tokenCollateralAddress) moreThanZero(amountCollateral) moreThanZero(amountDscToBurn) {

        burnDSC(amountDscToBurn);
        
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // This function already checks the health factor, so we don't need to do it here
    }

    /**
    * Function to allow the burning of user's DSC.
    * Amount to burn must be more than zero.
    *
    * Do we need to check if burn affects health factor? Probably not since its reducing the debt position of the user. However, will add for now and can remove in future
    *
    * @param amountDsc - the amount of DSC to burn
    *
    */
    function burnDSC(uint256 amountDsc) public moreThanZero(amountDsc) {
        s_dscMinted[msg.sender] -= amountDsc;
        //Attempt to transfer DSC from user to contract before we directly call the burn function of DSC contract
        bool success = i_dsc.transferFrom(msg.sender, address(this), amountDsc);

        //This conditional is hypothetically unreachable, because if the transferFrom fails, it will revert with the transferFrom error - If its been implemented correctly
        if(!success) {
            revert DSCEngine__TransferFailed();
        }

        i_dsc.burn(amountDsc);

        // Remove in future if not required - Don't think it is required
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * Mint function scales in complexity compared to simple minting because we need to verify that the amount of collateral is worth more than the amount of DSC. It will have to use PriceFeeds, checking values, etc
     *
     * @param amountDscToMint - the amount of Decentralised Stable Coin (DSC) to mint
     * @notice - we don't want to allow minting of 0, so use of modifier to not allow 0
     * @notice - They must have more collateral value than the minimum threshold we specify to maintain overcollateral protection. This will involve doing health factor check
     * @notice - THIS IS VERY SIMPLISTIC WHERE WE ARE NOT RETURNING OR CALCULATING HOW MANY TOKENS CAN BE MINTED
     */
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        // Update amount of DSC user has minted (amount of debt)
        s_dscMinted[msg.sender] += amountDscToMint;

        // Do health factor check to make sure user can mint DSC, else Revert the transaction and any changes that were going to occur on storage variables - e.g s_dscMinted
        _revertIfHealthFactorIsBroken(msg.sender);

        // Actually mint the DSC
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (!minted) {
            revert DSCEngine__MintFailed();
        }

        // Emit event - minted tokens
        emit DSCMinted(msg.sender, amountDscToMint);
    }


    // @note - In future, we should add feature to liquidate protocol if the protocl becomes insovlent, add feature to sweep extra amounts into treasury during liquidation
    /**
    * This function will liquidate a user's debt position if they are below the liquidation threshold. They must maintain a health factor above 1 to avoid liquidation.
    */
    // @note - This function will take as input the amount of debt that needs to be covered - i.e the amount of collateral that needs to be liquidated to maintain the health factor above 1, and to prevent our system collapsing by maintaining overcollateralisation
    // @note - We encourage people to act on liquidating bad positions of other users by giving them more collateral than what the DSC amount is that needs to be covered for.
    /** 
    * @notice - you can partially liquidate a user
    *
    * @notice - Our system reward users that liquidate bad positions with a 'liquidation bonus' for taking user funds
    * @notice - This function assumes the protocol maintains roughly 200% collateralisation in order for this to work - because otherwise we can't give bonuses
    * @notice - A known bug is that if the protocl were 100% or less collateralised, then we would not be able to give a bonus or incentivise liquidators. For example, if the price of the collateral plummeted before anyone could be liquidated.
    *
    * Need to check if user is below liquidation threshold, if not then revert
    *
    * @param tokenCollateralAddress - the address of the token that will be used as collateral to liquidate
    * @param user - the address of the user to liquidate
    * @param debtToCover - the amount of debt that needs to be covered (DSC to be burned to imrpove the users health)
    */
    function liquidate(address tokenCollateralAddress, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant() isAllowedToken(tokenCollateralAddress) {
        uint256 startingUserHealthFactor = _healthFactor(user);

        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        // We wanto to burn the user's DSC (debt) and take their collateral
        // e.g bad user now has $140 ETH, $100 DSC --> which is below our threshold and 200% overcollateralisation
        // Debt to cover from bad user is - $100
        // We need to calculate how much $100 DSC == ??? ETH?
        // Amount is ~0.05 ETH
        uint256 collateralTokenAmountFromDebtBeingCovered = getTokenAmountFromUSD(tokenCollateralAddress, debtToCover);


        // Want to calculate how much WETH we are going to give to liquidator, with the included 10% bonus
        // e.g (0.05 ETH * 10) / 100 = 0.005 ETH
        uint256 bonusCollateral = (collateralTokenAmountFromDebtBeingCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToGiveLiquidator = collateralTokenAmountFromDebtBeingCovered + bonusCollateral;

        // Need to give the liquidator the collateral and burn the DSC of the bad user
        

        
    }



    ////////////////////////
    // Internal Functions //
    ////////////////////////

    /**
     * This function is used to calculate the health factor of a user. Returns how close a user is to liquidation.
     * If user goes below '1', they can be liquidated.
     *
     * Need users total DSC minted, and their total collateral value
     *
     * @param userAddress - the address of the user to check
     */
    function _healthFactor(address userAddress) private view returns (uint256) {
        // Get user account information
        (uint256 totalDscMinted, uint256 totalCollateralValueInUSD) = _getAccountInfo(userAddress);

        // Will need thresholds so that we can use the account information to check health of the user. Calculate health factor ratio of total DSC minted against the total collateral value multiplied by the liquidation threshold
        uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        //Will be a very large number because of the exponent, but calling function can compare against 1e18 to determine if below minimum health score of 1
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * Private function to get the account information of a user's address. Returns the amount of DSC they have minted, and the amount of collateral value they have deposited
     *
     * @param userAddress - the address of the user to get account information for
     *
     */
    function _getAccountInfo(address userAddress)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUSD)
    {
        // Get user account information
        // total DSC minted is easy, we can use the mapping we have created
        totalDscMinted = s_dscMinted[userAddress];

        // To get the value of collateral in USD, we need to get the price of the collateral token/s that the user has deposited
        totalCollateralValueInUSD = getAccountCollateralValue(userAddress);
    }

    /**
     * Function to allow reverting of functions when the user's position is not healthy. Should not allow actions that jeopardise the project's stability.
     * 'Health Factor' is a term that they grabbed from Aave.
     *
     *  Check health factor - Do they have enough collateral?
     *  Revert if they don't have enough and have a bad health factor
     * @param userAddress - the address of the user to check
     *
     */
    function _revertIfHealthFactorIsBroken(address userAddress) internal view {
        uint256 userHealthFactor = _healthFactor(userAddress);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////////////
    // Public & External View Functions //
    //////////////////////////////////////

    /**
     * Public function to allow anyone to check the health factor score of a user.
     *
     * @param userAddress - the address of the user to check
     *
     */

    function getHealthFactor(address userAddress) external view returns(uint256 healthFactor){
        //Call the health factor function
        healthFactor = _healthFactor(userAddress);
        return healthFactor;
    }

    /**
     * Public function to allow anyone to know how much collateral value a user has. We can use this for health checks.
     * Will use Chainlink Price Feeds to get USD value of collateral
     *
     *
     */
    function getAccountCollateralValue(address userAddress) public view returns (uint256 totalCollateralValueInUSD) {
        // Initialise total collateral value
        totalCollateralValueInUSD = 0;

        // Need to loop through each collateral token, get the amount they have deposited, map that to the price in USD
        for (uint256 i = 0; i < s_tokenAddresses.length; i++) {
            // Get token address, use it to get the amount of that token the user has deposited, use the token and amount to calculate the USD value
            address token = s_tokenAddresses[i];
            uint256 amountDeposited = s_collateralDeposited[userAddress][token];

            // For each token, add the USD value to the total
            totalCollateralValueInUSD += getUsdValueOfToken(token, amountDeposited);
        }

        return totalCollateralValueInUSD;
    }

    /**
     * Function that will get the value of a token in USD from chainlink pricefeed. Based on the token address and the amount.
     * Chainlink PriceFeed returns the price of the token in USD to 8 decimal places. The amount we pass in is WEI and it has 18 decimal places. We need to standardise them for calculaitons.
     * Added state constant varaible to use for chainlink price feed returned values
     * @param tokenAddress - the address of the token
     * @param amount - the amount of the token
     *
     */
    function getUsdValueOfToken(address tokenAddress, uint256 amount) public view returns (uint256 usdValueOfToken) {
        // Get price from price feed
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);


        // REMEMBER THE /* */ WRAPPED AROUND A VARIABLE INDICATE THAT ITS NOT USED
        (
            /* uint80 roundID */
            ,
            int256 answer, // The price in USD - detailed as PRICE * e8 --> 8 decimal places
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        // Calculate USD value of token amount by turning the 8 decimal place 'answer' to 18 decimal places before multiplying by the amount (in WEI)
        usdValueOfToken = (uint256(answer) * ADDITIONAL_PRICEFEED_PRECISION) * amount;

        // We then divide the USD value by 10^18 to get the USD value of the token in an easily readable format
        usdValueOfToken = usdValueOfToken / PRECISION;

        return usdValueOfToken;
    }

    /**
    * Function to find out how much of an token is worth the provided USD amount in WEI
    * 1. We need the $/ETH price
    * 2. Divide the USD amount we have, by the price of ETH $/ETH from step 1
    * $2000 USD/ETH  ---> want to know how much token is worth $1000 USD ----> 1000/2000 = 0.5 ETH (not in WEI right now for demo purposes)
    *
    */
    function getTokenAmountFromUSD(address tokenAddress,uint256 usdAmountInWei) public view moreThanZero(usdAmountInWei) isAllowedToken(tokenAddress) returns (uint256) {
        // Get price of ETH from price feed - which is $/ETH. How do we get ETH/$?
        
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[tokenAddress]);


        // REMEMBER THE /* */ WRAPPED AROUND A VARIABLE INDICATE THAT ITS NOT USED
        (
            /* uint80 roundID */
            ,
            int256 price, // The price in USD - detailed as PRICE * e8 --> 8 decimal places
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        // Need to multiply 'usdAmountInWei' by 1^18 to be able to divide by 'price' in standardised format  
        // 'price' variable has 8 decimal places, we want 18 decimal places to be standardised for calculations
        // ($10e18 * 1e18) / ($2000e8 * 1e10) = 0.005,000,000,000,000,000 = 0.005 ETH
        return(usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_PRICEFEED_PRECISION);

    }





    /////////////////////////////////////////////////////////
    // Public & External View Functions - Getter Functions //
    /////////////////////////////////////////////////////////

    function getPrecision() public view returns (uint256) {
        return PRECISION;
    }

    function getAdditionalPriceFeedPrecision() public view returns (uint256) {
        return ADDITIONAL_PRICEFEED_PRECISION;
    }

    function getLiquidationThreshold() public view returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() public view returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() public view returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_tokenAddresses;
    }

    function getDSCAddress() public view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeedAddress(address token) public view returns (address) {
        return s_priceFeeds[token];
    }


    /**
     * TODO - add liquidation bonus constant variable when get to point of doing liquidation function and write in getter function
     */
}

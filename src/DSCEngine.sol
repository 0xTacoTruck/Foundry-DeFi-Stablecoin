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
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Allows us to use transfer functions already written in accorance with the standards
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    //immutable variable for the Decentralised Stablecoin Contract to allow us to call its functions and stuff
    DecentralisedStableCoin private immutable i_dsc;

    ////////////////////
    // Errors         //
    ////////////////////
    error DSCEngine__AmountMustBeMoreThanZero();

    error DSCEngine__CollateralTokenIsNotAllowed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
    error DSCEngine__StableCoinAddressMustNotBeZero();
    error DSCEngine__TransferFailed();

    ////////////////////
    // Events         //
    ////////////////////

    //Remember Events can have up to 3 indexed parameters - indexed parameters AKA Topics
    //Indexed Params are searchable by topic
    event DSCEngine__CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DscAddress) {
        // Make sure that there is the same number of tokens and pricefeeds passed in
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
        }

        //Make sure we have an address passed in
        if (DscAddress == address(0)) {
            revert DSCEngine__StableCoinAddressMustNotBeZero();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }

        i_dsc = DecentralisedStableCoin(DscAddress);
    }

    ////////////////////////
    // External Functions //
    ////////////////////////

    /**
     * We need to know what collateral they want to deposit, done by passing in the address of the collateral they want, plus we want the amount of collateral they want to deposit
     * @param tokenCollateralAddress - the address of the collateral token to deposit
     * @param amountCollateral - the amount of collateral to deposit
     * @dev we don't want to allow anyone to deposit nothing, so use of modifier to not allow 0 as an amount
     * @dev we only want collateral tokens that are allowed by our project
     *
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral) // Amount must be more than 0
        isAllowedToken(tokenCollateralAddress) // Is the collateral token allowed
        nonReentrant // Non-Reentrant modifier to prevent re-entrancy attacks
    {
        // Deposit collateral and update amount of collateral deposited for the user
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        // Emit the deposited collateral event since we updated storage variable
        emit DSCEngine__CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // Transfer collateral from user to our contract
        // @note - relies on the tokenCollateralAddress inheriting from IERC20 interface
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        // Revert if not successful
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function depositCollateralAndMintDSC(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // Deposit collateral, update user amount of deposited collateral, mint our stablecoin ERC20 that is aligned with the amount of collateral deposited
    }

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}

    function burnDSC() external {}

    function mintDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////
    // Internal Functions //
    ////////////////////////
}

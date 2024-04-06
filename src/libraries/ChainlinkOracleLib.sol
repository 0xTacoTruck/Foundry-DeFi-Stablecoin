// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


/**
* @title ChainlinkOracleLib
* @author TheUser1935
* @notice ChainlinkOracleLib is a library for the Chainlink Oracle and is based upon the library and supllementary materials covered during the Cyfrin DeFi stablecoin lesson
* @notice This library is used to check the Chainlink Oracle for stale data
*       - If a price is stale, the function will revert and essentially make the DSC Engine unusable - this is by design.
*       - If a price is not stale, the DSC Engine will continue to function as expected or it will return to operating as expected
*
*
* @dev - Freeze if the price becomes stale
*       - So if Chainlink network explodes and you have a lot of money locked in the protocol .... too bad. Known issue, this is to protect the stability of our DSC system and -
*   - our token -> DSC
*/


// Import Aggregator V3 Interface so we can get pricefeeds and do our checks of the pricefeeds
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


library ChainlinkOracleLib {

    /*//////////////////////////////////////////////////////////////
                           State Variables
    //////////////////////////////////////////////////////////////*/

    //@note - we should query what the heartbeat is for the specific pricefeed, but learning purposes we are just going to hardcode the value to use
    uint256 private constant TIMEOUT = 3 hours; //3 * 60 * 60 = 10800 seconds

    /*//////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error ChainlinkOracleLib__PriceIsStale();


    /*//////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/


    //Returns the same values as the 'LatestRoundData' function of the AggregatorV3Interface
    //We can use this function instead of directly calling the AggregatorV3Interface getLatestRoundData function to ensure we either have good data to work with, or revert
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80) {
        // Get the latest Round Data
        (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        //Calculate the time passed from last update in seconds
        uint256 secondsSinceUpdate = block.timestamp - updatedAt;

        //Use if statement to revert if the time passed means the price is stale - revert with our own error
        if(secondsSinceUpdate > TIMEOUT) {
            revert ChainlinkOracleLib__PriceIsStale();
        }

        //Return the value of pricefeed
        return(roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
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

pragma solidity ^0.8.19;

/**
 * @title Decentralised Stable Coin
 * @dev This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin
 * @author TheUser1935
 * Collateral: Exogenous (ETH (wETH), BTC (wBTC))
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract to be managed by the Decentralised Stablecoin Engine. This contract is the ERC20 implementation of the Decentralised Stablecoin that will be used in the implementation of our stablecoin system.
 */

//Burnable allows the burning of tokens, as well as standard ERC20 functions
import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

//Allows to to have ownership assinged for tokens and allow restricted functionality to owner
/*@note - Open Zeppelin have made Ownable requiring the address of the contract owner as a parameter*/

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

////////////////////
// Errors         //
////////////////////

contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    // Error for when amount is less than zero
    error DecentralisedStableCoin__AmountMustBeMoreThanZero();

    // Error for when amount is more than balance
    error DecentralisedStableCoin__BurnAmountExceedsBalance();

    // Error to not allow sending to address(0)
    error DecentralisedStableCoin__ZeroAddressNotAllowed();

    ////////////////////
    // Constructor    //
    ////////////////////

    /* @note - Because of the change that Open Zeppelin did in requiring contract owner address to be passed to the constructor for Ownable, I'm using msg.sender for now until development of the stablecoin engine is in progress. I want to make sure I can pass or set the owner contract address to the engine at some point (intial thinking) 
    * @note - Because I decided to roll-back the version of Open Zeppelin contracts from 5.x.x -> 4.8.3, the Ownable contract does not require the contract owner address to be passed in the constructor, because of this version. I do want to explore and confirm if my thinking was on track for this constructor input though

    constructor() ERC20("DecentralisedStableCoin", "DSC") Ownable(msg.sender) {}

     @note ------ THE FOLLOWING PARAGRAPH WAS TAKEN FROM THE HELPERCONFIG.SOL FILE, WHERE IT WAS POSITIONED JUST BEFORE CALLING TRANSFER OWNSERSHIP ------
                "It is intersting to see that the transfer is done manually. If you refer to my notes on the DecentralisedStableCoin.sol file, you will see that I was leaning toward doing it in the constructor as part of initialisation. Perhaps that is overthinking and introduces an issue that im not aware of"
    
    */
    constructor() ERC20("DecentralisedStableCoin", "DSC") Ownable() {}

    //There is 2 major functions we want our engine to own:
    // 1.function to burn tokens
    // 2.function to mint tokens

    //Function to burn tokens
    //onlyOwner is a modifier from the ownable contract of the Open Zeppelin library
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        // Make sure person has that much token to burn
        // Can't burn zero tokens, revert with error
        if (_amount <= 0) {
            revert DecentralisedStableCoin__AmountMustBeMoreThanZero();
        }
        // Can't burn more than the balance of person
        if (balance < _amount) {
            revert DecentralisedStableCoin__BurnAmountExceedsBalance();
        }

        //Super keyword tells solidity to use the function of this name that sits in inherrited file - in our case this is ERC20Burnable.sol
        super.burn(_amount);
    }

    //Function to mint tokens

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            // Don't want to allow accidental minting to zero address
            revert DecentralisedStableCoin__ZeroAddressNotAllowed();
        }

        if (_amount <= 0) {
            // Can't mint nothing
            revert DecentralisedStableCoin__AmountMustBeMoreThanZero();
        }

        //Call actual minting function now
        // This minting function sits in ERC20.sol
        _mint(_to, _amount);

        return true;
    }
}

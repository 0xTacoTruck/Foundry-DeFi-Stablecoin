// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralisedStableCoin} from "../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDSC is Script {

    DSCEngine dscEngine;
    DecentralisedStableCoin dsCoin;
    HelperConfig hc;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    address user = makeAddr("USER");



    function run() external returns(DecentralisedStableCoin, DSCEngine, HelperConfig) {

        
        

         hc = new HelperConfig();

        (address wethUSDPriceFeed,address wbtcUSDPriceFeed,address wethToken,address wbtcToken,uint256 deployerKey) = hc.activeNetworkConfig();


        tokenAddresses = [wethToken, wbtcToken];
        priceFeedAddresses = [wethUSDPriceFeed, wbtcUSDPriceFeed];
        
        vm.startBroadcast();
       
    
        dsCoin = new DecentralisedStableCoin();
        //Need to call the constructor here and pass in all the params: address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DscAddress
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses,address(dsCoin));


        // @note - intersting to see that the transfer is done manually. If you refer to my notes on the DecentralisedStableCoin.sol file, you will see that I was leaning toward doing it in the constructor as part of initialisation. Perhaps that is overthinking and introduces an issue that im not aware of
        //Transfer ownership to the DSCEngine contract
        dsCoin.transferOwnership(address(dscEngine));

        vm.stopBroadcast();

        return (dsCoin, dscEngine, hc);

    }
}

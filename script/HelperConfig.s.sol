// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    uint8 public constant DECIMALS = 8;

    int256 public constant ETH_INITIAL_ANSWER = 2000e8; // 2000 USD

    int256 public constant BTC_INITIAL_ANSWER = 1000e8; // 1000 USD

    //Structu to use for multiple chain configs - e.g. pricefeeds, token addresses, etc
    struct NetworkConfig {
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address wethToken;
        address wbtcToken;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD - FIND IN CHAINLINK DOCS
            wbtcUSDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, // BTC / USD - FIND IN CHAINLINK DOCS
            wethToken: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, // WETH ERC20 token address - FIND IN CHAINLINK DOCS
            wbtcToken: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, // WBTC ERC20 token address - FIND IN CHAINLINK DOCS
            deployerKey: vm.envUint("SEPOLIA_METAMASK_PRIVATE_KEY") // Sepolia Account Private Key to deploy onto Seplolia network
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        //Need MockV3 Aggregator because we can't access a real one on Anvil. Need this for both ETH and BTC

        vm.startBroadcast();
        // Pass the number of decimals to use for answer, pass the initial price of ETH to USD
        MockV3Aggregator ethUSDPriceFeed = new MockV3Aggregator(DECIMALS, ETH_INITIAL_ANSWER);

        //Mock ETH ERC20 token so we can fake depositing it into our system
        ERC20Mock ethMockToken = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        // Pass the number of decimals to use for answer, pass the initial price of BTC to USD
        MockV3Aggregator btcUSDPriceFeed = new MockV3Aggregator(DECIMALS, BTC_INITIAL_ANSWER);

        //Mock BTC ERC20 token so we can fake depositing it into our system
        ERC20Mock btcMockToken = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);

        vm.stopBroadcast();

        //Set the active network config
        anvilNetworkConfig = NetworkConfig({
            wethUSDPriceFeed: address(ethUSDPriceFeed),
            wbtcUSDPriceFeed: address(btcUSDPriceFeed),
            wethToken: address(ethMockToken),
            wbtcToken: address(btcMockToken),
            deployerKey: vm.envUint("ANVIL_0_PRIVATE_KEY")
        });

        return anvilNetworkConfig;
    }
}

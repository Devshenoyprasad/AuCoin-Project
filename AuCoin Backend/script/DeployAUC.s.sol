// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AUCEngine} from "../src/AUCEngine.sol";

contract DeployAUC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (AUCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address AuUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        // if (block.chainid == 31337) {
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        AUCEngine AucEngine = new AUCEngine(
            tokenAddresses,
            priceFeedAddresses,
            AuUsdPriceFeed
        );
        vm.stopBroadcast();
        return (AucEngine, helperConfig);
    }
}

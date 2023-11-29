//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEnigne.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract deployDSCEnigne is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address WBTCUSDPriceFeed,
            address WETHUSDPriceFeed,
            address WETH,
            address WBTC,
            uint256 delpoyKey
        ) = helperConfig.config();

        tokenAddresses.push(WETH);
        tokenAddresses.push(WBTC);
        priceFeedAddresses.push(WETHUSDPriceFeed);
        priceFeedAddresses.push(WBTCUSDPriceFeed);

        vm.startBroadcast(delpoyKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            DecentralizedStableCoin(dsc)
        );
        vm.stopBroadcast();
        return (dscEngine, helperConfig);
    }
}

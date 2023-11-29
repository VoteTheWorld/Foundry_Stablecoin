//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public config;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    struct NetworkConfig {
        address WBTCUSDPriceFeed;
        address WETHUSDPriceFeed;
        address WETH;
        address WBTC;
        uint256 delpoyKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            getSepoliaConfig();
        } else {
            getorCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() internal {
        config.WBTCUSDPriceFeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        config.WETHUSDPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        config.WETH = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
        config.WBTC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        config.delpoyKey = vm.envUint("PRIVATE_KEY");
    }

    function getorCreateAnvilConfig() internal {
        if (config.WBTCUSDPriceFeed == address(0)) {
            vm.startBroadcast();
            MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
                DECIMALS,
                ETH_USD_PRICE
            );
            ERC20Mock wethMock = new ERC20Mock(
                "WETH",
                "WETH",
                msg.sender,
                1000e8
            );

            MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
                DECIMALS,
                BTC_USD_PRICE
            );
            ERC20Mock wbtcMock = new ERC20Mock(
                "WBTC",
                "WBTC",
                msg.sender,
                1000e8
            );
            vm.stopBroadcast();
            config.WBTCUSDPriceFeed = address(btcUsdPriceFeed);
            config.WETHUSDPriceFeed = address(wbtcMock);
            config.WETH = address(ethUsdPriceFeed);
            config.WBTC = address(wethMock);
            config.delpoyKey = vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY");
        }
    }
}

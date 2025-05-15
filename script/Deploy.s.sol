// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {LootBox} from "../src/LootBox.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployScript is Script {
    function run() external returns (LootBox, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // Create Subscription
            CreateSubscription createSubscription = new CreateSubscription();
            config.subscriptionId = createSubscription.createSubscription(config.vrfCoordinator, config.deployerKey);

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator, config.deployerKey, config.subscriptionId, config.link
            );
        }

        vm.startBroadcast(config.deployerKey);
        LootBox lootBox = new LootBox(
            config.openFee, config.vrfCoordinator, config.subscriptionId, config.keyHash, config.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add Consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(lootBox), config.vrfCoordinator, config.deployerKey, config.subscriptionId);

        return (lootBox, helperConfig);
    }
}

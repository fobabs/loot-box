// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken as LinkToken} from "@chainlink-contracts/v0.8/mocks/MockLinkToken.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

interface IVRFCoordinatorV2_5 {
    function createSubscription() external returns (uint256 subId);
    function addConsumer(uint256 subId, address consumer) external;
}

contract CreateSubscription is Constants, Script {
    function run() external {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 deployer = helperConfig.getConfig().deployerKey;

        return createSubscription(vrfCoordinator, deployer);
    }

    function createSubscription(address _vrfCoordinator, uint256 _deployer) public returns (uint256) {
        console.log("Creating subscription on chainId: ", block.chainid);

        uint256 subId = 0;
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(_deployer);
            subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployer);
            subId = IVRFCoordinatorV2_5(_vrfCoordinator).createSubscription();
            vm.stopBroadcast();
        }
        console.log("Your subscription Id is:", subId);
        return subId;
    }
}

contract FundSubscription is Constants, Script {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        uint256 deployer = helperConfig.getConfig().deployerKey;
        address linkToken = helperConfig.getConfig().link;

        fundSubscription(vrfCoordinator, deployer, subscriptionId, linkToken);
    }

    function fundSubscription(address _vrfCoordinator, uint256 _deployer, uint256 _subscriptionId, address _linkToken)
        public
    {
        console.log("Funding subscription on chainId: ", block.chainid);

        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(_deployer);
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            LinkToken(_linkToken).transferAndCall(_vrfCoordinator, FUND_AMOUNT, abi.encode(_subscriptionId));
        }
    }
}

contract AddConsumer is Constants, Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("LootBox", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        uint256 deployer = helperConfig.getConfig().deployerKey;

        addConsumer(_mostRecentlyDeployed, vrfCoordinator, deployer, subscriptionId);
    }

    function addConsumer(address contractAddress, address vrfCoordinator, uint256 _deployer, uint256 _subscriptionId)
        public
    {
        console.log("Adding Consumer Contract on chainId: ", block.chainid);

        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(_deployer);
            VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(_subscriptionId, contractAddress);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployer);
            IVRFCoordinatorV2_5(vrfCoordinator).addConsumer(_subscriptionId, contractAddress);
            vm.stopBroadcast();
        }
    }
}

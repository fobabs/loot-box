// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "../src/utils/Constants.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink-contracts/v0.8/mocks/MockLinkToken.sol";

contract HelperConfig is Constants, Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 openFee;
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig private activeNetworkConfig;

    constructor() {
        if (block.chainid == ANVIL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthNetworkConfig();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthNetworkConfig();
        } else if (block.chainid == MAINNET_CHAIN_ID) {
            activeNetworkConfig = getEthNetworkConfig();
        } else {
            revert HelperConfig__InvalidChainId(block.chainid);
        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getEthNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            openFee: OPEN_FEE,
            vrfCoordinator: VRF_COORDINATOR_MAINNET_ADDRESS,
            subscriptionId: 0,
            keyHash: KEY_MAINNET_HASH,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            link: LINK_MAINNET_ADDRESS,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaEthNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            openFee: OPEN_FEE,
            vrfCoordinator: VRF_COORDINATOR_SEPOLIA_ADDRESS,
            subscriptionId: 0,
            keyHash: KEY_SEPOLIA_HASH,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            link: LINK_SEPOLIA_ADDRESS,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        // Generate a Mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        MockLinkToken linkTokenMock = new MockLinkToken();
        vm.stopBroadcast();

        return NetworkConfig({
            openFee: OPEN_FEE,
            vrfCoordinator: address(vrfCoordinatorMock),
            subscriptionId: 0,
            keyHash: KEY_SEPOLIA_HASH,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            link: address(linkTokenMock),
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}

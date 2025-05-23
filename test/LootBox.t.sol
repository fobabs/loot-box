// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {LootBox} from "../src/LootBox.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeployScript} from "../script/Deploy.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC721Mock} from "./mocks/ERC721Mock.sol";
import {Constants} from "../src/utils/Constants.sol";

contract LootBoxTest is Constants, Test {
    LootBox public lootBox;
    HelperConfig public helperConfig;
    ERC20Mock public erc20Token;
    ERC721Mock public erc721Token;

    uint256 public openFee;
    address public vrfCoordinator;
    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit;

    address public contractOwner;
    address public player = makeAddr("player");
    uint256 public constant FUND_AMOUNT = 5 ether;

    function setUp() public {
        DeployScript deployer = new DeployScript();
        (lootBox, helperConfig) = deployer.run();
        vm.deal(player, FUND_AMOUNT);

        erc20Token = new ERC20Mock();
        erc721Token = new ERC721Mock();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        openFee = config.openFee;
        vrfCoordinator = config.vrfCoordinator;
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;

        contractOwner = vm.addr(config.deployerKey);
    }

    function test_Deployment() public view {
        assertEq(lootBox.getOpenFee(), openFee);
    }

    // function test_ExpectEmitOnAddReward() public {
    //     vm.expectEmit(true, false, false, true);
    //     emit LootBox.RewardAdded(0, LootBox.RewardType.POINTS, address(0), 100, 50);
    //     vm.prank(lootBox.owner());
    //     lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
    // }

    function test_DeploymentOwner() public view {
        assertEq(lootBox.owner(), contractOwner);
    }

    function test_AddRewardPoints() public {
        vm.prank(contractOwner);
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
        _assertReward(0, LootBox.RewardType.POINTS, address(0), 100, 50);
    }

    function test_AddRewardERC20() public {
        vm.prank(contractOwner);
        lootBox.addReward(LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
        _assertReward(0, LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
    }

    function test_AddRewardERC721() public {
        vm.prank(contractOwner);
        lootBox.addReward(LootBox.RewardType.ERC721, address(erc721Token), 0, 10);
        _assertReward(0, LootBox.RewardType.ERC721, address(erc721Token), 0, 10);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _assertReward(
        uint256 _index,
        LootBox.RewardType _rewardType,
        address _tokenAddress,
        uint256 _amount,
        uint256 _weight
    ) private view {
        LootBox.Reward memory rewards = lootBox.getRewards(_index);
        assertEq(uint8(rewards.rewardType), uint8(_rewardType));
        assertEq(rewards.tokenAddress, _tokenAddress);
        assertEq(rewards.amount, _amount);
        assertEq(rewards.weight, _weight);
    }
}

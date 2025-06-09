// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
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

    bytes public constant NON_OWNER_ERROR_MESSAGE = "Only callable by owner";

    modifier ownerPrank() {
        vm.prank(contractOwner);
        _;
    }

    function setUp() public {
        DeployScript deployer = new DeployScript();
        (lootBox, helperConfig) = deployer.run();
        vm.deal(player, FUND_AMOUNT);

        erc20Token = new ERC20Mock();
        erc20Token.mint(address(lootBox), FUND_AMOUNT);
        erc721Token = new ERC721Mock();
        erc721Token.mint(address(lootBox), 1);

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
    //     vm.prank(contractOwner);
    //     lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
    // }

    function test_DeploymentOwner() public view {
        assertEq(lootBox.owner(), contractOwner);
    }

    function test_AddRewardPoints() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
        _assertReward(0, LootBox.RewardType.POINTS, address(0), 100, 50);
    }

    function test_AddRewardERC20() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
        _assertReward(0, LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
    }

    function test_AddRewardERC721() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.ERC721, address(erc721Token), 1, 10);
        _assertReward(0, LootBox.RewardType.ERC721, address(erc721Token), 1, 10);
    }

    function test_AddRewardRevertsNonOwner() public {
        vm.prank(player);
        vm.expectRevert(NON_OWNER_ERROR_MESSAGE);
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
    }

    function test_AddRewardRevertsInvalidAddress() public ownerPrank {
        vm.expectRevert(LootBox.LootBox__InvalidAddress.selector);
        lootBox.addReward(LootBox.RewardType.ERC20, address(0), 100, 50);
    }

    function test_UpdateFee() public ownerPrank {
        uint256 newFee = 0.5 ether;
        lootBox.updateFee(newFee);
        assertEq(lootBox.getOpenFee(), newFee);
    }

    function test_UpdateFeeRevertsNonOwner() public {
        vm.prank(player);
        vm.expectRevert(NON_OWNER_ERROR_MESSAGE);
        uint256 newFee = 0.5 ether;
        lootBox.updateFee(newFee);
    }

    function test_OpenLootBoxRevertsNoReward() public {
        vm.prank(player);
        vm.expectRevert(LootBox.LootBox__NoRewardsConfigured.selector);
        lootBox.openLootBox{value: openFee}();
    }

    function test_OpenLootBoxRevertsInvalidETHAmount() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
        vm.prank(player);
        uint256 playerOpenFee = 0.3 ether;
        vm.expectRevert(abi.encodeWithSelector(LootBox.LootBox__IncorrectETHAmount.selector, playerOpenFee, openFee));
        lootBox.openLootBox{value: playerOpenFee}();
    }

    // function test_OpenLootBox() public ownerPrank {
    //     lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
    //     vm.prank(player);
    //     vm.expectEmit(true, true, false, true);
    //     emit LootBox.LootBoxOpened(player, 1);
    //     lootBox.openLootBox{value: openFee}();
    // }

    function test_FulfillRandomWordsPoints() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
        _openLootBoxAndFulfillRandomWords();
        assertEq(lootBox.getPointsBalance(), 100);
    }

    function test_FulfillRandomWordsERC20() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
        _openLootBoxAndFulfillRandomWords();
        assertEq(erc20Token.balanceOf(player), 1000);
    }

    function test_FulfillRandomWordsERC721() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.ERC721, address(erc721Token), 1, 10);
        _openLootBoxAndFulfillRandomWords();
        assertEq(erc721Token.ownerOf(1), player);
    }

    function test_FulfillRandomWordsRevertsInvalidRequest() public ownerPrank {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(90, address(lootBox));
    }

    function test_WithdrawETH() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.POINTS, address(0), 100, 50);
        vm.prank(player);
        lootBox.openLootBox{value: openFee}();
        vm.prank(contractOwner);
        lootBox.withdrawETH();
        assertEq(address(lootBox).balance, 0);
        assertEq(contractOwner.balance, openFee);
    }

    function test_WithdrawTokens() public ownerPrank {
        lootBox.addReward(LootBox.RewardType.ERC20, address(erc20Token), 1000, 30);
        _openLootBoxAndFulfillRandomWords();
        uint256 balanceBeforeWithdrawal = erc20Token.balanceOf(address(lootBox));
        vm.prank(contractOwner);
        lootBox.withdrawTokens(address(erc20Token), 1000);
        assertEq(erc20Token.balanceOf(address(lootBox)), balanceBeforeWithdrawal - 1000);
        assertEq(erc20Token.balanceOf(contractOwner), 1000);
    }

    function test_WithdrawRevertsNonOwner() public {
        vm.prank(player);
        vm.expectRevert(NON_OWNER_ERROR_MESSAGE);
        lootBox.withdrawETH();
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

    function _openLootBoxAndFulfillRandomWords() private {
        vm.prank(player);
        vm.recordLogs();
        lootBox.openLootBox{value: openFee}();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[2];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lootBox));
    }
}

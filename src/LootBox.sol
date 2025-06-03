// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink-contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink-contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title LootBox Contract
 * @author FOBABS
 * @notice Manages the opening of loot boxes and distribution of rewards
 * @dev Inherits VRFConsumerBaseV2Plus for VRF functionality
 */
contract LootBox is VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LootBox__InvalidAddress();
    error LootBox__NoRewardsConfigured();
    error LootBox__TransferFailed();
    error LootBox__IncorrectETHAmount(uint256 sent, uint256 expected);

    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/
    enum RewardType {
        POINTS,
        ERC20,
        ERC721
    }

    struct Reward {
        RewardType rewardType;
        address tokenAddress; // For ERC20/ERC721, 0x0 for points
        uint256 amount; // Amount for ERC20/points, tokenId for ERC721
        uint256 weight; // Rarity weight
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    Reward[] private s_rewards;
    uint256 private s_totalWeight;
    uint256 private s_openFee;
    mapping(uint256 => address) private s_requestToSender;
    uint256 private s_pointsBalance;

    // VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event LootBoxOpened(address indexed sender, uint256 indexed requestId);
    event RewardDistributed(address indexed sender, RewardType rewardType, address tokenAddress, uint256 amount);
    event RewardAdded(
        uint256 indexed rewardId, RewardType rewardType, address tokenAddress, uint256 amount, uint256 weight
    );
    event FeeUpdated(uint256 newFee);

    /**
     * @notice Deploys the LootBox contract
     * @param _openFee The fee to open a loot box
     * @param _vrfCoordinator The address of the VRF coordinator
     * @param _subscriptionId The id of the VRF subscription
     * @param _keyHash The hash of the key used to generate randomness
     * @param _callbackGasLimit The gas limit of the callback function
     */
    constructor(
        uint256 _openFee,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_openFee = _openFee;
        i_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Withdraws a specified amount of a given ERC20 token
     * @dev Only callable by the contract owner
     * @param _token The address of the ERC20 token to withdraw
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    /**
     * @notice Withdraws the entire balance of this contract in ETH
     * @dev Only callable by the contract owner
     */
    function withdrawETH() external onlyOwner {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        if (!success) revert LootBox__TransferFailed();
    }

    /**
     * @notice Adds a reward to the list of rewards
     * @dev Only callable by the contract owner
     * @param _rewardType The type of the reward
     * @param _tokenAddress The address of the ERC20 token for the reward or address(0) for points
     * @param _amount The amount of tokens/points for the reward
     * @param _weight The weight of the reward
     */
    function addReward(RewardType _rewardType, address _tokenAddress, uint256 _amount, uint256 _weight)
        external
        onlyOwner
    {
        if (_rewardType != RewardType.POINTS) {
            if (_tokenAddress == address(0)) revert LootBox__InvalidAddress();
        }

        s_rewards.push(Reward({rewardType: _rewardType, tokenAddress: _tokenAddress, amount: _amount, weight: _weight}));

        s_totalWeight += _weight;

        emit RewardAdded(s_rewards.length - 1, _rewardType, _tokenAddress, _amount, _weight);
    }

    /**
     * @notice Updates the fee required to open a loot box
     * @dev Only callable by the contract owner
     * @param _newFee The new fee amount
     */
    function updateFee(uint256 _newFee) external onlyOwner {
        s_openFee = _newFee;

        emit FeeUpdated(_newFee);
    }

    /**
     * @notice Opens a loot box and rewards the caller with a random reward
     */
    function openLootBox() external payable {
        if (s_rewards.length == 0) revert LootBox__NoRewardsConfigured();
        if (msg.value != s_openFee) revert LootBox__IncorrectETHAmount(msg.value, s_openFee);

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        // aderyn-fp-next-line(reentrancy-state-change)
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        s_requestToSender[requestId] = msg.sender;

        emit LootBoxOpened(msg.sender, requestId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Callback function for the VRF Coordinator when a random number is generated
     * @dev This function is called by the VRF Coordinator when a random number is generated
     * @param _requestId The ID of the request that this random number is fulfilling
     * @param _randomWords The random number generated by the VRF
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        address user = s_requestToSender[_requestId];
        if (user == address(0)) revert LootBox__InvalidAddress();

        uint256 randomValue = _randomWords[0] % s_totalWeight;
        uint256 currentWeight = 0;
        Reward[] memory rewards = s_rewards;
        uint256 rewardsLength = rewards.length;

        // aderyn-fp-next-line(costly-loop)
        for (uint256 i = 0; i < rewardsLength; i++) {
            currentWeight += rewards[i].weight;
            if (randomValue < currentWeight) {
                _distributeReward(user, i);
                break;
            }
        }

        delete s_requestToSender[_requestId];
    }

    // aderyn-ignore-next-line(internal-function-used-once)
    /**
     * @notice Distributes the reward to the user
     * @dev This function is called in fulfillRandomWords to distribute the reward to the user
     * @param _user The address of the user to distribute the reward to
     * @param _rewardId The ID of the reward to distribute
     */
    function _distributeReward(address _user, uint256 _rewardId) private {
        Reward memory reward = s_rewards[_rewardId];

        if (reward.rewardType == RewardType.POINTS) {
            s_pointsBalance += reward.amount;
        } else if (reward.rewardType == RewardType.ERC20) {
            IERC20(reward.tokenAddress).safeTransfer(_user, reward.amount);
        } else if (reward.rewardType == RewardType.ERC721) {
            IERC721(reward.tokenAddress).safeTransferFrom(address(this), _user, reward.amount);
        }

        emit RewardDistributed(_user, reward.rewardType, reward.tokenAddress, reward.amount);
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL VIEW FUNCTION
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the number of rewards configured in the contract
     * @return The number of rewards configured in the contract
     */
    function getRewardsCount() external view returns (uint256) {
        return s_rewards.length;
    }

    function getOpenFee() external view returns (uint256) {
        return s_openFee;
    }

    function getRewards(uint256 _rewardId) external view returns (Reward memory) {
        return s_rewards[_rewardId];
    }

    function getPointsBalance() external view returns (uint256) {
        return s_pointsBalance;
    }
}

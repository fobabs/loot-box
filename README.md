# Randomized Loot Box Smart Contract

## Overview

This is a Solidity smart contract for a Randomized Loot Box system built on Ethereum. Users can pay a fee to open a loot box and receive a random reward (ERC20 tokens, ERC721 NFTs, or on-chain points). The randomness is provided by Chainlink VRF to ensure fairness and unpredictability.

## Features

- Configurable rewards with different types (Points, ERC20, ERC721) and rarity weights  
- Owner-controlled reward setup and fee management  
- Secure random number generation using Chainlink VRF  
- Support for ERC20 token payments  
- Event emissions for tracking loot box openings and reward distributions  
- Withdrawal functions for contract owner  
- View functions for querying reward configurations  

## Prerequisites

- Solidity `^0.8.20`  
- OpenZeppelin Contracts  
- Chainlink VRF V2  
- Deployed on a network with Chainlink VRF support (e.g., Sepolia testnet)  

## Dependencies

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
````

## Contract Details

### Constructor

```solidity
constructor(
    address _paymentToken,    // ERC20 token for payments
    uint256 _openFee,         // Fee to open a loot box
    uint64 _subscriptionId    // Chainlink VRF subscription ID
)
```

### Main Functions

* `addReward`: Owner adds a new reward with type, token address, amount, and weight
* `updateFee`: Owner updates the loot box opening fee
* `openLootBox`: Users pay to open a loot box and request a random reward
* `fulfillRandomWords`: Internal Chainlink VRF callback to process random number
* `distributeReward`: Internal function to transfer rewards to users
* `withdrawTokens` / `withdrawETH`: Owner withdraws contract funds
* `getRewardsCount`: View function to get total number of configured rewards

## Events

* `LootBoxOpened(address user, uint256 requestId)`
* `RewardDistributed(address user, RewardType rewardType, address tokenAddress, uint256 amount)`
* `RewardAdded(uint256 rewardId, RewardType rewardType, address tokenAddress, uint256 amount, uint256 weight)`
* `FeeUpdated(uint256 newFee)`

## Deployment

1. Set up a Chainlink VRF subscription and fund it
2. Deploy an ERC20 token contract for payments (or use an existing one)
3. Deploy the LootBox contract with:

   * Payment token address
   * Initial opening fee
   * Chainlink VRF subscription ID
4. Configure rewards using `addReward`
5. Ensure the contract has sufficient tokens/NFTs for rewards

## Usage

* Users approve the contract to spend their payment tokens
* Users call `openLootBox` to pay and request a reward
* Chainlink VRF generates a random number
* Contract distributes the reward based on the random number and reward weights

## Security Considerations

* Ensure proper access control (`onlyOwner` for sensitive functions)
* Verify token transfers and approvals
* Monitor Chainlink VRF subscription balance
* Test reward weight distribution for fairness
* Implement reentrancy protection where applicable

## Testing

* Use a testnet like Sepolia with Chainlink VRF support
* Deploy mock ERC20/ERC721 contracts for testing
* Test reward distribution probabilities
* Verify event emissions and state changes
* Test edge cases (zero weights, empty rewards, failed transfers)

## License

MIT License

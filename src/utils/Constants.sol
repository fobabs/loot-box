// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract Constants {
    uint256 internal constant OPEN_FEE = 0.5 ether;

    // Chain IDs
    uint256 internal constant OP_MAINNET_CHAIN_ID = 10;
    uint256 internal constant OP_SEPOLIA_CHAIN_ID = 11_155_420;
    uint256 internal constant ANVIL_CHAIN_ID = 31_337;

    uint256 internal constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // VRF Values
    uint32 internal constant CALLBACK_GAS_LIMIT = 2_500_000;
    // Mainnet
    address internal constant LINK_MAINNET_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant VRF_COORDINATOR_MAINNET_ADDRESS = 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a;
    bytes32 internal constant KEY_MAINNET_HASH = 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9;
    // Sepolia
    address internal constant LINK_SEPOLIA_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address internal constant VRF_COORDINATOR_SEPOLIA_ADDRESS = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 internal constant KEY_SEPOLIA_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    // Mock
    uint96 internal constant MOCK_BASE_FEE = 0.2 ether;
    uint96 internal constant MOCK_GAS_PRICE = 1e9;
    int256 internal constant MOCK_WEI_PER_UNIT_LINK = 4e15;
}

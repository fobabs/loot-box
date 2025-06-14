// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address account, uint256 tokenId) external {
        _mint(account, tokenId);
    }
}

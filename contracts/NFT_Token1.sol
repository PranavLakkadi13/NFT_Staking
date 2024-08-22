// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.25;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTToken1 is ERC721 {
    constructor() ERC721("NFTToken1", "NFT1") {}

    function mintToken(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "TOKEN1";
    }

}
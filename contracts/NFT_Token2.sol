// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTToken2 is ERC721 {
    constructor() ERC721("NFTToken2", "NFT2") {}

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "TOKEN1";
    }

}
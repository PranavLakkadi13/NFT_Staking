// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { NFTStaking } from "../contracts/NFT_Staking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { RewardToken } from "../contracts/RewardToken.sol";
import { NFTToken1 } from "../contracts/NFT_Token1.sol";
import { NFTToken2 } from "../contracts/NFT_Token2.sol";
import { Test, console } from "forge-std/Test.sol";

contract STakingTest is Test {
    NFTStaking staking;
    IERC20 rewardToken;
    IERC721 nftToken1;
    IERC721 nftToken2;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new RewardToken();
        nftToken1 = new NFTToken1();
        nftToken2 = new NFTToken2();
        staking = new NFTStaking();
        staking.initialize(rewardToken, 1e10, 1000, 1000);
        vm.stopPrank();
    }

    function testSettingUp() public {
        vm.expectRevert();
        staking.initialize(rewardToken, 1e10, 1000, 1000);
    }

    
}


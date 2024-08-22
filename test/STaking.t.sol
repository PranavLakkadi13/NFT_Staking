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
    NFTToken1 nftToken1;
    NFTToken2 nftToken2;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");


    event Staked(address indexed user, uint256 tokenIds);
    event Unstaked(address indexed user, uint256 tokenIds);
    event RewardsClaimed(address indexed user, uint256 amount);


    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new RewardToken();
        nftToken1 = new NFTToken1();
        nftToken2 = new NFTToken2();
        staking = new NFTStaking();
        staking.initialize(rewardToken,nftToken1, 1e10, 1000, 1000);
        for (uint i = 0; i < 10; i++) {
            nftToken1.mintToken(owner, i);
            nftToken1.approve(address(staking), i);
            nftToken2.mintToken(owner, i);
            nftToken2.approve(address(staking), i);
        }
        vm.stopPrank();
    }

    function testSettingUp() public {
        vm.expectRevert();
        staking.initialize(rewardToken,nftToken1, 1e10, 1000, 1000);
        assertEq(staking.getRewardToken(), address(rewardToken));
        assertEq(staking.getNftToken(), address(nftToken1));
        assertEq(staking.getRewardPerBlock(), 1e10);
        assertEq(staking.getUnbondingPeriod(), 1000);
        assertEq(staking.getRewardClaimDelay(), 1000);
        nftToken1.tokenURI(0);
    }

    function teststakes() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
    }

    function testRevertIfWrongNFTAddressPassed() public {
        vm.expectRevert();
        staking.stake_single_token(address(nftToken2),0);
    }

    function testRevertIFTheTokenAlreadyStaked() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
        vm.expectRevert();
        staking.stake_single_token(address(nftToken1),0);
    }
    
    function testSTakedData() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
        assertEq(staking.getStakeBlockNumberOfToken(owner, 0),1);
        assertEq(staking.getTokenIfClaimed(owner, 0),false);
        assertEq(staking.getTokenIfUnbonding(owner, 0), false);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        assertEq(staking.getTokensStaked(owner) , tokenIds);
        assertEq(staking.getTokensStaked(owner).length, 1);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 0), 0);
    }

    function testStakeEventEMit() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit Staked(owner, 0);
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
    }

    function testMultipleStakes() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        vm.startPrank(owner);
        staking.stake_Multiple_Tokens(address(nftToken1),tokenIds);
        vm.stopPrank();
        assertEq(staking.getTokensStaked(owner) , tokenIds);
        assertEq(staking.getTokensStaked(owner).length, 3);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 0),1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 1),1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 2),1);
        assertEq(staking.getTokenIfClaimed(owner, 0),false);
        assertEq(staking.getTokenIfClaimed(owner, 1),false);
        assertEq(staking.getTokenIfClaimed(owner, 2),false);
        assertEq(staking.getTokenIfUnbonding(owner, 0), false);
        assertEq(staking.getTokenIfUnbonding(owner, 1), false);
        assertEq(staking.getTokenIfUnbonding(owner, 2), false);
    }


    function testVentEmitOnMultipleTokenStakes() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        vm.expectEmit(true, true, false, false);
        emit Staked(owner, 0);
        emit Staked(owner, 1);
        emit Staked(owner, 2);
        staking.stake_Multiple_Tokens(address(nftToken1),tokenIds);

        vm.stopPrank();
    }

    function testExpectRevertIFTokenALreadySTakedInMultipleDeposit() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1),0);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 0;
        tokenIds[2] = 2;
        vm.expectRevert();
        staking.stake_Multiple_Tokens(address(nftToken1),tokenIds);

        vm.stopPrank();
    }

    function testExpectRevertWhenNonOwnerCalls() public {
        vm.startPrank(user1);
        vm.expectRevert();
        staking.setRewardClaimDelay(120);
        vm.expectRevert();
        staking.setRewardPerBlock(1e18);
        vm.expectRevert();
        staking.setUnbondingPeriod(1000798);
        vm.expectRevert();
        staking.setRewardToken(IERC20(address(nftToken2)));
        vm.stopPrank();
    }

    function testExpectStakeToHoldIFContractPaused() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1), 1);
        staking.pause();
        vm.expectRevert();
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
    }

    function testNewSTakingCanContinueWhenUnpaused() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1), 1);
        staking.pause();
        vm.expectRevert();
        staking.stake_single_token(address(nftToken1),0);
        staking.unpause();
        staking.stake_single_token(address(nftToken1),0);
        vm.stopPrank();
    }


    function testRevertSinceUnstakingANonStakedToken() public {
        vm.startPrank(owner);
        vm.expectRevert();
        staking.unstake_single_token(0);
        vm.stopPrank();
    }

    function testSingleUnstakeTokens() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1), 0);
        staking.unstake_single_token(0);
        vm.stopPrank();
        assertEq(staking.getTokensStaked(owner).length, 1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 0), 1);
        assertEq(staking.getTokenIfClaimed(owner, 0), false);
        assertEq(staking.getTokenIfUnbonding(owner, 0), true);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 0), 1);
    }

    function testShouldnotUnstakeIfContractPaused() public {
        vm.startPrank(owner);
        staking.stake_single_token(address(nftToken1), 0);
        staking.pause();
        vm.expectRevert();
        staking.unstake_single_token(0);
        vm.stopPrank();
    }
}


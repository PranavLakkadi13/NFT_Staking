// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { NFTStaking } from "../contracts/NFT_Staking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { RewardToken } from "../contracts/RewardToken.sol";
import { NFTToken1 } from "../contracts/NFT_Token1.sol";
import { NFTToken2 } from "../contracts/NFT_Token2.sol";
import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract STakingTest is Test {
    NFTStaking staking;
    RewardToken rewardToken;
    NFTToken1 nftToken1;
    NFTToken2 nftToken2;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");


    event Staked(address indexed user, uint256 indexed tokenIds);
    event Unstaked(address indexed user, uint256 indexed tokenIds);
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    event WithdrawNFTs(address indexed user, uint256 indexed tokenIds);


    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new RewardToken();
        nftToken1 = new NFTToken1();
        nftToken2 = new NFTToken2();
        staking = new NFTStaking();
        staking.initialize(address(rewardToken),nftToken1, 1e10, 1000, 1000);
        for (uint i = 0; i < 10; i++) {
            nftToken1.mintToken(owner, i);
            nftToken1.approve(address(staking), i);
            nftToken2.mintToken(owner, i);
            nftToken2.approve(address(staking), i);
        }
        rewardToken.transferOwnership(address(staking));
        vm.stopPrank();
    }

    function testSettingUp() public {
        vm.expectRevert();
        staking.initialize(address(rewardToken),nftToken1, 1e10, 1000, 1000);
        assertEq(staking.getRewardToken(), address(rewardToken));
        assertEq(staking.getNftToken(), address(nftToken1));
        assertEq(staking.getRewardPerBlock(), 1e10);
        assertEq(staking.getUnbondingPeriod(), 1000);
        assertEq(staking.getRewardClaimDelay(), 1000);
        assertEq(nftToken1.tokenURI(0), "TOKEN10");
        assertEq(nftToken2.tokenURI(0), "TOKEN20");
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


    function testEVentEmitOnMultipleTokenStakes() public {
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

    function testUnstakeMultipleTokens() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_Multiple_Tokens(tokenIds);
        vm.stopPrank();
        assertEq(staking.getTokensStaked(owner).length, 3);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 0), 1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 1), 1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 2), 1);
        assertEq(staking.getTokenIfClaimed(owner, 0), false);
        assertEq(staking.getTokenIfClaimed(owner, 1), false);
        assertEq(staking.getTokenIfClaimed(owner, 2), false);
        assertEq(staking.getTokenIfUnbonding(owner, 0), true);
        assertEq(staking.getTokenIfUnbonding(owner, 1), true);
        assertEq(staking.getTokenIfUnbonding(owner, 2), true);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 0), 1);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 1), 1);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 2), 1);
    }

    function testUnstakeMultipleTokensFailIfContractPaused() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.pause();
        vm.expectRevert();
        staking.unstake_Multiple_Tokens(tokenIds);
        vm.stopPrank();
    }

    function testEventEmissionWhenWithdrawn() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        vm.expectEmit(true, true, false, false);
        emit Unstaked(owner, 0);
        emit Unstaked(owner, 1);
        emit Unstaked(owner, 2);
        staking.unstake_Multiple_Tokens(tokenIds);
        vm.stopPrank();
    }

    function testPartiallyWIthdrawnTokensCantBeReSTakedUntillFullyWIthdraw()  public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        vm.expectRevert();
        staking.stake_single_token(address(nftToken1), 0);
        vm.stopPrank();
    }

    function testShouldRevertIfUnstakingAalreadyUnstakedToken() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        vm.expectRevert();
        staking.unstake_single_token(0);
        vm.stopPrank();
    }


    function testShouldRevertIfTheunstakedTokenIsWithdrawnBeforeUnboundTime() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.expectRevert();
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
    }


    function testSHouldRevertIfInvalidArraySIzeIsPassed() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        uint256[] memory tokenIds2 = new uint256[](0);
        vm.expectRevert();
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
    }

    function testSHouldWithdrawNFTThatisDOneStaking() public { 
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
        assertEq(staking.getTokensStaked(owner).length, 3);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 0), 0);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 1), 1);
        assertEq(staking.getStakeBlockNumberOfToken(owner, 2), 1);
        assertEq(staking.getTokenIfClaimed(owner, 0), true);
        assertEq(staking.getTokenIfClaimed(owner, 1), false);
        assertEq(staking.getTokenIfClaimed(owner, 2), false);
        assertEq(staking.getTokenIfUnbonding(owner, 0), false);
        assertEq(staking.getTokenIfUnbonding(owner, 1), true);
        assertEq(staking.getTokenIfUnbonding(owner, 2), false);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 0), 0);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 1), 1);
        assertEq(staking.getWithdrawTimeOfSTakedToken(owner, 2), 0);
    }

    function testSHouldFailToSTakeOrWithdrawWhenArraySIzeisWrong() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert();
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        vm.expectRevert();
        staking.unstake_Multiple_Tokens(tokenIds);
        vm.roll(1200);
        vm.expectRevert();
        staking.withdrawNFTs(tokenIds);
        vm.stopPrank();
    }

    function testSHouldRevertIfALreadyWIthdrawnTokenIsBeingWIthdrawn() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        staking.withdrawNFTs(tokenIds2);
        vm.expectRevert();
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
    }

    function testSHouldAllowSTakeOfWithdrawnTokenAndAllowItsWithdraw() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        staking.withdrawNFTs(tokenIds2);
        nftToken1.approve(address(staking), 0);
        vm.expectEmit(true, true, false, false);
        emit Staked(owner, 0);
        staking.stake_single_token(address(nftToken1), 0);
        vm.expectRevert();
        staking.withdrawNFTs(tokenIds2);
        staking.unstake_single_token(0);
        vm.roll(2700);
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
    }

    function testEventEMissionWhenTokenIsWithdrawn() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        vm.expectEmit(true, true, false, false);
        emit WithdrawNFTs(owner, 0);
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();

        assertEq(nftToken1.ownerOf(0), owner);
    }

    function testRewardsCLaim() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        vm.expectEmit(true, true, false, false);
        emit WithdrawNFTs(owner, 0);
        staking.withdrawNFTs(tokenIds2);
        vm.roll(block.number + staking.getRewardClaimDelay());
        staking.claimRewards();
        vm.stopPrank();
    }


    function testShouldRevertWhenWithdrawingBeforeDelay() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        vm.expectEmit(true, true, false, false);
        emit WithdrawNFTs(owner, 0);
        staking.withdrawNFTs(tokenIds2);
        // vm.expectRevert();
        staking.claimRewards();
        vm.stopPrank();
    }


    function testShouldRevertWhenTokensareNotWIthdrawn() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(1200);
        vm.expectRevert();
        staking.claimRewards();
        vm.stopPrank();
    }



    function testProxyImplememtation() public {
        staking = new NFTStaking();
        bytes memory data = abi.encodeWithSignature("initialize(address,address,uint256,uint256,uint256)", address(rewardToken), address(nftToken1), 1e10, 10000, 10000);
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking),data);
        staking = NFTStaking(address(proxy));
        vm.startPrank(owner);

        for (uint i = 0; i < 10; i++) {
            nftToken1.approve(address(staking), i);
            nftToken2.approve(address(staking), i);
        }


        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.unstake_single_token(0);
        staking.unstake_single_token(1);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        vm.roll(10000 + 5);
        staking.withdrawNFTs(tokenIds2);
        vm.stopPrank();
    }
}



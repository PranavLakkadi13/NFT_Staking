// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {NFTStaking} from "../contracts/NFT_Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {RewardToken} from "../contracts/RewardToken.sol";
import {NFTToken1} from "../contracts/NFT_Token1.sol";
import {NFTToken2} from "../contracts/NFT_Token2.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyTest is Test {
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
        // staking.initialize(address(rewardToken), IERC721(address(nftToken1)), 100, 1, 1);
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,uint256,uint256,uint256)",
            address(rewardToken),
            address(nftToken1),
            100,
            1,
            1
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking), data);
        staking = NFTStaking(address(proxy));
        for (uint256 i = 0; i < 10; i++) {
            nftToken1.mintToken(owner, i);
            nftToken1.approve(address(staking), i);
            nftToken2.mintToken(owner, i);
            nftToken2.approve(address(staking), i);
        }
        rewardToken.transferOwnership(address(staking));
    }

    function testStakingFeatures() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        
        (uint256 initail_Reward,) = staking.getRewardUpdateData(0);
        assert(initail_Reward == 100);
        console.log("Block Number", block.number);
        vm.roll(100);
        console.log("Block Number", block.number);
        staking.setRewardPerBlock(50);
        console.log("Block Number", block.number);
        vm.roll(150);
        console.log("Block Number", block.number);
        // staking.setRewardPerBlock(500);
        // console.log("Block Number", block.number);
        // vm.roll(250);
        // console.log("Block Number", block.number);
        // uint256 x = staking.getCOunteOFUpdateOfReward();
        // assert(x == 3);

        staking.getRewardCounterOfToken(owner, 0);

        staking.unstake_single_token(0);
        console.log("Current blocknumber ", block.number);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        // vm.roll(1200);
        // console.log("Reward Counter", staking.getCOunteOFUpdateOfReward());
        uint256[] memory tokenIds3 = staking.getRewardCounterOfToken(owner, 0);
        vm.roll(252);
        console.log("Block Number", block.number);
        uint256 y = staking.calculateReward(owner, 0, staking.getRewardCounterOfToken(owner, 0), staking.getUnbondingBlockNumberOfToken(owner, 0));
        console.log(y);
        vm.expectEmit(true, true, false, false);
        emit WithdrawNFTs(owner, 0);
        staking.withdrawNFTs(tokenIds2, tokenIds3);
        vm.expectEmit(true, true, false, false);
        emit RewardsClaimed(owner, 12450);
        staking.claimRewards();
        vm.stopPrank();
    }

    function testUpdate() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        staking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        staking.pause();
        vm.roll(1000);

        NFTStaking newImpl = new NFTStaking();
        newImpl.initialize(address(rewardToken), IERC721(nftToken1), 10, 10, 10);
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,uint256,uint256,uint256)",
            address(rewardToken),
            address(nftToken1),
            100,
            1,
            1
        );
        // ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), data);
        // staking.upgradeToAndCall(address(newImpl), data);
        staking.upgradeToAndCall(address(newImpl), "");
        // staking.initialize(address(rewardToken), IERC721(nftToken1), 10, 10, 10);
        // staking = NFTStaking(address(proxy));
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        staking.unpause();
        staking.unstake_single_token(0);
        staking.getTokenIfUnbonding(owner, 0);  
        staking.getRewardUpdateData(1);
        staking.getRewardPerBlockRecent();
        
        // staking.unstake_single_token(0);

        // uint256[] memory tokenIds2 = new uint256[](1);
        // tokenIds2[0] = 0;
        // console.log("Current blocknumber ", block.number);
        // staking.withdrawNFTs(tokenIds2, staking.getRewardCounterOfToken(owner, 0));
        vm.stopPrank();
    }
}

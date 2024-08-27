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
    NFTStaking FinalStaking;

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
        staking.initialize(address(rewardToken), IERC721(address(nftToken1)), 100, 1, 1);
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,uint256,uint256,uint256)",
            address(rewardToken),
            address(nftToken1),
            100,
            1,
            1
        );
        console.log("The Below Deployemnt is the Proxy creation");
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking), data);
        FinalStaking = NFTStaking(address(proxy));
        FinalStaking.getNftToken();
        for (uint256 i = 0; i < 5; i++) {
            nftToken1.mintToken(owner, i);
            nftToken1.approve(address(FinalStaking), i);
            nftToken2.mintToken(owner, i);
            nftToken2.approve(address(FinalStaking), i);
        }
        FinalStaking.getNftToken();
        FinalStaking.getRewardUpdateData(0);
        rewardToken.transferOwnership(address(FinalStaking));
        vm.stopPrank();
    }

    function testStakingFeatures() public {
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        FinalStaking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        
        (uint256 initail_Reward,) = FinalStaking.getRewardUpdateData(0);
        assert(initail_Reward == 100);
        console.log("Block Number", block.number);
        vm.roll(100);
        console.log("Block Number", block.number);
        FinalStaking.setRewardPerBlock(50);
        console.log("Block Number", block.number);
        vm.roll(150);
        console.log("Block Number", block.number);
        // FinalStaking.setRewardPerBlock(500);
        // console.log("Block Number", block.number);
        // vm.roll(250);
        // console.log("Block Number", block.number);
        // uint256 x = FinalStaking.getCOunteOFUpdateOfReward();
        // assert(x == 3);

        FinalStaking.getRewardCounterOfToken(owner, 0);

        FinalStaking.unstake_single_token(0);
        console.log("Current blocknumber ", block.number);
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        // vm.roll(1200);
        // console.log("Reward Counter", FinalStaking.getCOunteOFUpdateOfReward());
        uint256[] memory tokenIds3 = FinalStaking.getRewardCounterOfToken(owner, 0);
        vm.roll(252);
        console.log("Block Number", block.number);
        uint256 y = FinalStaking.calculateReward(owner, 0, FinalStaking.getRewardCounterOfToken(owner, 0), staking.getUnbondingBlockNumberOfToken(owner, 0));
        console.log(y);
        vm.expectEmit(true, true, false, false);
        emit WithdrawNFTs(owner, 0);
        FinalStaking.withdrawNFTs(tokenIds2, tokenIds3);
        vm.expectEmit(true, true, false, false);
        emit RewardsClaimed(owner, 12450);
        FinalStaking.claimRewards();
        vm.stopPrank();
    }

    function testUpdate() public {
        vm.startPrank(owner);
        FinalStaking.getNftToken();
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        FinalStaking.stake_Multiple_Tokens(address(nftToken1), tokenIds);
        FinalStaking.pause();
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
        FinalStaking.upgradeToAndCall(address(newImpl), data);
        // FinalStaking.upgradeToAndCall(address(newImpl), "");
        // FinalStaking.initialize(address(rewardToken), IERC721(nftToken1), 10, 10, 10);
        // FinalStaking = NFTStaking(address(proxy));
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 0;
        FinalStaking.unpause();
        FinalStaking.unstake_single_token(0);
        FinalStaking.getTokenIfUnbonding(owner, 0);  
        FinalStaking.getRewardUpdateData(1);
        FinalStaking.getRewardPerBlockRecent();
        
        // FinalStaking.unstake_single_token(0);

        // uint256[] memory tokenIds2 = new uint256[](1);
        // tokenIds2[0] = 0;
        // console.log("Current blocknumber ", block.number);
        // FinalStaking.withdrawNFTs(tokenIds2, FinalStaking.getRewardCounterOfToken(owner, 0));
        vm.stopPrank();
    }
}

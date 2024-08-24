// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.25;

// import {NFTStaking} from "../contracts/NFT_Staking.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {RewardToken} from "../contracts/RewardToken.sol";
// import {NFTToken1} from "../contracts/NFT_Token1.sol";
// import {NFTToken2} from "../contracts/NFT_Token2.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract ProxyTest is Test {
//     NFTStaking staking;
//     RewardToken rewardToken;
//     NFTToken1 nftToken1;
//     NFTToken2 nftToken2;

//     address owner = makeAddr("owner");
//     address user1 = makeAddr("user1");
//     address user2 = makeAddr("user2");

//     event Staked(address indexed user, uint256 indexed tokenIds);
//     event Unstaked(address indexed user, uint256 indexed tokenIds);
//     event RewardsClaimed(address indexed user, uint256 indexed amount);
//     event WithdrawNFTs(address indexed user, uint256 indexed tokenIds);

//     function setUp() public {
//         vm.startPrank(owner);
//         rewardToken = new RewardToken();
//         nftToken1 = new NFTToken1();
//         nftToken2 = new NFTToken2();
//         staking = new NFTStaking();
//         bytes memory data = abi.encodeWithSignature(
//             "initialize(address,address,uint256,uint256,uint256)",
//             address(rewardToken),
//             address(nftToken1),
//             1e10,
//             10000,
//             10000
//         );
//         ERC1967Proxy proxy = new ERC1967Proxy(address(staking), data);
//         staking = NFTStaking(address(proxy));
//         for (uint256 i = 0; i < 10; i++) {
//             nftToken1.mintToken(owner, i);
//             nftToken1.approve(address(staking), i);
//             nftToken2.mintToken(owner, i);
//             nftToken2.approve(address(staking), i);
//         }
//         rewardToken.transferOwnership(address(staking));
//     }

//     function testStakingFeatures() public {
//         vm.startPrank(owner);
//         staking.stake_single_token(address(nftToken1), 0);
//         staking.stake_single_token(address(nftToken1), 1);
//         staking.stake_single_token(address(nftToken1), 2);
//         staking.unstake_single_token(0);
//         uint256[] memory tokenIds = new uint256[](1);
//         tokenIds[0] = 0;
//         vm.expectRevert();
//         staking.withdrawNFTs(tokenIds);
//         vm.roll(10002);
//         staking.withdrawNFTs(tokenIds);
//         staking.claimRewards();
//         vm.stopPrank();
//     }

//     function testUpgrade() public {
//         vm.startPrank(owner);
//         staking.stake_single_token(address(nftToken1), 0);
//         staking.stake_single_token(address(nftToken1), 1);
//         staking.stake_single_token(address(nftToken1), 2);
//         staking.unstake_single_token(0);
//         uint256[] memory tokenIds = new uint256[](1);
//         tokenIds[0] = 0;
//         vm.expectRevert();
//         staking.withdrawNFTs(tokenIds);
//         vm.roll(10002);
//         staking.withdrawNFTs(tokenIds);
//         staking.claimRewards();

//         NFTStaking newStaking = new NFTStaking();
//         bytes memory data = abi.encodeWithSignature(
//             "initialize(address,address,uint256,uint256,uint256)",
//             address(rewardToken),
//             address(nftToken1),
//             1e10,
//             100,
//             100
//         );
//         // ERC1967Proxy proxy = new ERC1967Proxy(address(newStaking),data);
//         // newStaking = NFTStaking(address(proxy));

//         staking.upgradeToAndCall(address(newStaking), data);
//         for (uint256 i = 0; i < 10; i++) {
//             nftToken1.approve(address(newStaking), i);
//             nftToken2.approve(address(newStaking), i);
//         }
//         rewardToken.transferOwnership(address(newStaking));
//         newStaking.stake_single_token(address(nftToken1), 0);
//         newStaking.stake_single_token(address(nftToken1), 1);
//         newStaking.stake_single_token(address(nftToken1), 2);
//         newStaking.unstake_single_token(0);
//         uint256[] memory tokenIds2 = new uint256[](1);
//         tokenIds[0] = 0;
//         vm.expectRevert();
//         newStaking.withdrawNFTs(tokenIds2);
//         vm.roll(10002);
//         newStaking.withdrawNFTs(tokenIds2);
//         newStaking.claimRewards();
//         vm.stopPrank();
//     }
// }

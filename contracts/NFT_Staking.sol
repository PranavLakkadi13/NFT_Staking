// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTStaking is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    IERC20 public rewardToken;
    uint256 public rewardPerBlock;
    uint256 public unbondingPeriod;
    uint256 public rewardClaimDelay;
 
    struct Stake {
        uint256[] tokenIds;
        uint256 lastClaimBlock;
        uint256 stakedAt;
        bool isUnbonding;
    }

    mapping(address => mapping(address => Stake)) public stakes;

    event Staked(address indexed user, address indexed nftContract, uint256[] tokenIds);
    event Unstaked(address indexed user, address indexed nftContract, uint256[] tokenIds);
    event RewardsClaimed(address indexed user, uint256 amount);

    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _unbondingPeriod,
        uint256 _rewardClaimDelay
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();

        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        unbondingPeriod = _unbondingPeriod;
        rewardClaimDelay = _rewardClaimDelay;
    }

    function stake(address nftContract, uint256[] memory tokenIds) external whenNotPaused {
        require(tokenIds.length > 0, "No NFTs to stake");

        Stake storage userStake = stakes[msg.sender][nftContract];
        require(!userStake.isUnbonding, "Currently unbonding");

        userStake.stakedAt = block.number;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenIds[i]);
            userStake.tokenIds.push(tokenIds[i]);
        }

        if (userStake.lastClaimBlock == 0) {
            userStake.lastClaimBlock = block.number;
        }

        emit Staked(msg.sender, nftContract, tokenIds);
    }

    function unstake(address nftContract, uint256[] memory tokenIds) external whenNotPaused {
        Stake storage userStake = stakes[msg.sender][nftContract];
        require(userStake.tokenIds.length >= tokenIds.length, "Invalid unstake amount");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(nftContract).transferFrom(address(this), msg.sender, tokenIds[i]);
            _removeTokenFromStake(userStake.tokenIds, tokenIds[i]);
        }

        userStake.isUnbonding = true;
        emit Unstaked(msg.sender, nftContract, tokenIds);
    }

    function withdrawNFTs(address nftContract) external {
        Stake storage userStake = stakes[msg.sender][nftContract];
        require(userStake.isUnbonding, "Not in unbonding state");
        require(block.number >= userStake.stakedAt + unbondingPeriod, "Unbonding period not over");

        for (uint256 i = 0; i < userStake.tokenIds.length; i++) {
            IERC721(nftContract).transferFrom(address(this), msg.sender, userStake.tokenIds[i]);
        }
        
        delete stakes[msg.sender][nftContract];
    }

    function claimRewards(address nftContract) external whenNotPaused {
        uint256 reward = calculateReward(msg.sender, nftContract);
        require(reward > 0, "No rewards available");

        rewardToken.transfer(msg.sender, reward);

        Stake storage userStake = stakes[msg.sender][nftContract];
        userStake.lastClaimBlock = block.number;

        emit RewardsClaimed(msg.sender, reward);
    }

    function calculateReward(address user, address nftContract) public view returns (uint256) {
        Stake storage userStake = stakes[user][nftContract];
        uint256 blocksStaked = block.number - userStake.lastClaimBlock;
        uint256 reward = blocksStaked * rewardPerBlock * userStake.tokenIds.length;
        return reward;
    }

    function _removeTokenFromStake(uint256[] storage tokenIds, uint256 tokenId) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                tokenIds[i] = tokenIds[tokenIds.length - 1];
                tokenIds.pop();
                break;
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

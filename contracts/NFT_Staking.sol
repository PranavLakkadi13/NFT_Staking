// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RewardToken} from "./RewardToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTStaking is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    ///////////////////////////////////////////////////////////////////////
    /////////////////  State Variables  ///////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    struct rewardData {
        uint256 rewarddata;
        uint256 blockNumberOfRewardUpdate;
    }

    struct Rewards {
        mapping(uint256 updateCOunter => rewardData) rewards;
        uint256 updateCounter;
    }

    RewardToken private s_rewardToken;
    IERC721 private s_nftToken;
    Rewards private s_rewards;
    uint256 private s_unbondingPeriod;
    uint256 private s_rewardClaimDelay;

    struct data {
        bool isWithdrawn;
        bool isUnbonding;
        uint256 unBondingBlockNumber;
        uint256 UnstakeTime;
        uint256 DepositTime;
        uint256 claimRewards;
        uint256 claimRewardBlockNumber;
        uint256 RewardTrackerBlock;
    }

    struct Stake {
        uint256[] tokenIds;
        mapping(uint256 => data) stateData;
        uint256 claimRewards;
    }

    mapping(address user_address => Stake) private stakes;

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Errors   ///////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    error NFTStaking__IncorrectNFTToken();
    error NFTStaking__IncorrectTokenIdToStake();
    error NFTStaking__InvalidArraySize();
    error NFTStaking__AlreadyStaked();
    error NFTStaking__IncorrectTokenIdToWithdraw(uint256 tokenId);
    error NFTStaking__IncorrectWithdrawOfAlreadyUnstakedToken(uint256 tokenId);
    error NFTStaking__NoRewardsToCliam();
    error NFTStaking__IncorrectTokenIdToWithdrawStillUnbonding(uint256 tokenId);
    error NFTStaking__IncorrectTokenIdToWithdrawUnbondingBlockNumberIsInFuture(uint256 tokenId);

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Events   ///////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    event Staked(address indexed user, uint256 indexed tokenIds);
    event Unstaked(address indexed user, uint256 indexed tokenIds);
    event WithdrawNFTs(address indexed user, uint256 indexed tokenIds);
    event RewardsClaimed(address indexed user, uint256 indexed amount);

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Constructor  ///////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function initialize(
        address _rewardToken,
        IERC721 _nftToken,
        uint256 _rewardPerBlock,
        uint256 _unbondingPeriod,
        uint256 _rewardClaimDelay
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();

        s_nftToken = _nftToken;
        s_rewardToken = RewardToken(address(_rewardToken));

        Rewards storage rewards = s_rewards;
        rewards.rewards[rewards.updateCounter].rewarddata = _rewardPerBlock;
        rewards.rewards[rewards.updateCounter].blockNumberOfRewardUpdate = block.number;
        rewards.updateCounter++;

        s_unbondingPeriod = _unbondingPeriod;
        s_rewardClaimDelay = _rewardClaimDelay;
    }

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Core Logic Functions  //////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /**
     * @dev The function is used to stake a single token
     * @param nftContract the address of the NFT contract
     * @param tokenId the token id to stake
     * @notice The user can only stake the token only if the contract is not paused
     */
    function stake_single_token(address nftContract, uint256 tokenId) public whenNotPaused {
        if (nftContract != address(s_nftToken)) {
            revert NFTStaking__IncorrectNFTToken();
        }

        Stake storage userStake = stakes[msg.sender];

        if (userStake.stateData[tokenId].DepositTime > 0 && userStake.stateData[tokenId].isWithdrawn == false) {
            revert NFTStaking__AlreadyStaked();
        }

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        userStake.tokenIds.push(tokenId);
        userStake.stateData[tokenId].DepositTime = block.number;
        userStake.stateData[tokenId].isWithdrawn = false;
        userStake.stateData[tokenId].isUnbonding = false;
        userStake.stateData[tokenId].RewardTrackerBlock = block.number;

        emit Staked(msg.sender, tokenId);
    }

    /**
     * @dev The function is used to stake multiple tokens at once it internally calls the stake_single_token function
     * @param nftContract the address of the nft contract
     * @param tokenIds the array of the token ids to stake
     * @notice The user can only stake the token only if the contract is not paused
     */
    function stake_Multiple_Tokens(address nftContract, uint256[] memory tokenIds) external whenNotPaused {
        if (tokenIds.length == 0) {
            revert NFTStaking__InvalidArraySize();
        }

        uint256 arrayLength = tokenIds.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            stake_single_token(nftContract, tokenIds[i]);
        }
    }

    /**
     * @dev The function is used to unstake a single token
     * @param tokenId the token id to unstake
     * @notice The user can only unstake the token only if the contract is not paused
     */
    function unstake_single_token(uint256 tokenId) public whenNotPaused {
        Stake storage userStake = stakes[msg.sender];

        if (userStake.stateData[tokenId].isUnbonding == true) {
            revert NFTStaking__IncorrectWithdrawOfAlreadyUnstakedToken(tokenId);
        }

        if (userStake.stateData[tokenId].DepositTime == 0) {
            revert NFTStaking__IncorrectTokenIdToWithdraw(tokenId);
        }

        userStake.stateData[tokenId].isUnbonding = true;
        userStake.stateData[tokenId].unBondingBlockNumber = block.number + s_unbondingPeriod;
        userStake.stateData[tokenId].UnstakeTime = block.number;

        emit Unstaked(msg.sender, tokenId);
    }

    /**
     * @dev The function is used to unstake multiple tokens at once it internally calls the unstake_single_token function
     * @param tokenIds the array of the token ids to unstake
     * @notice The user can only unstake the token only if the contract is not paused
     */
    function unstake_Multiple_Tokens(uint256[] calldata tokenIds) external whenNotPaused {
        if (tokenIds.length == 0) {
            revert NFTStaking__InvalidArraySize();
        }

        uint256 arrayLength = tokenIds.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            unstake_single_token(tokenIds[i]);
        }
    }

    /**
     * @dev The function is used to withdraw a single token or multiple tokens
     * @param tokenIds the token id to withdraw or ids
     * @notice The user can only withdraw the token only if the contract is not paused and is done unbounding
     */
    function withdrawNFTs(uint256[] calldata tokenIds, uint256[] calldata RewardData) external {
        Stake storage userStake = stakes[msg.sender];
        uint256 tempValu = tokenIds[0];

        if (tokenIds.length == 0) {
            revert NFTStaking__InvalidArraySize();
        }
        if (userStake.stateData[tempValu].isUnbonding == false) {
            revert NFTStaking__IncorrectTokenIdToWithdrawStillUnbonding(tokenIds[0]);
        }

        if (userStake.stateData[tempValu].unBondingBlockNumber >= block.number) {
            revert NFTStaking__IncorrectTokenIdToWithdrawUnbondingBlockNumberIsInFuture(userStake.stateData[tempValu].unBondingBlockNumber);
        }

        s_nftToken.transferFrom(address(this), msg.sender, tempValu);
        uint256 TheRewardsClaimable = calculateReward(msg.sender, tempValu, RewardData);
        userStake.claimRewards += TheRewardsClaimable;
        userStake.stateData[tempValu].claimRewards = TheRewardsClaimable;
        userStake.stateData[tempValu].claimRewardBlockNumber = block.number + s_rewardClaimDelay;
        userStake.stateData[tempValu].isWithdrawn = true;
        userStake.stateData[tempValu].isUnbonding = false;
        userStake.stateData[tempValu].unBondingBlockNumber = 0;
        userStake.stateData[tempValu].UnstakeTime = 0;
        userStake.stateData[tempValu].DepositTime = 0;

        emit WithdrawNFTs(msg.sender, tokenIds[0]);
    }

    function claimRewards() external whenNotPaused {
        uint256 reward;
        Stake storage userStake = stakes[msg.sender];

        if (userStake.claimRewards == 0) {
            revert NFTStaking__NoRewardsToCliam();
        }

        uint256 arrayLength = userStake.tokenIds.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            if (userStake.stateData[userStake.tokenIds[i]].claimRewardBlockNumber >= block.number) {
                reward += userStake.stateData[userStake.tokenIds[i]].claimRewards;
                userStake.stateData[userStake.tokenIds[i]].claimRewards = 0;
                userStake.stateData[userStake.tokenIds[i]].claimRewardBlockNumber = 0;
            }
        }

        userStake.claimRewards - reward;

        s_rewardToken.mint(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    function calculateReward(address user, uint256 tokenId, uint256[] calldata RewardData)
        public
        view
        returns (uint256 reward)
    {
        Stake storage userStake = stakes[user];
        uint256 length = RewardData.length - 1;
        uint256 start_time = userStake.stateData[tokenId].RewardTrackerBlock;
        if (length == 0) {
            reward += s_rewards.rewards[RewardData[0]].rewarddata * (block.number - start_time);
            return reward;
        }
        for (uint256 i = 0; i < length; i++) {
            uint256 v1 = s_rewards.rewards[i].blockNumberOfRewardUpdate;
            uint256 v2 = s_rewards.rewards[i + 1].blockNumberOfRewardUpdate;
            reward = (v2 - v1) * s_rewards.rewards[RewardData[i]].rewarddata;
        }
        reward += s_rewards.rewards[RewardData[length]].rewarddata
            * (block.number - s_rewards.rewards[RewardData[length]].blockNumberOfRewardUpdate);
        reward += s_rewards.rewards[RewardData[0]].rewarddata
            * (s_rewards.rewards[RewardData[1]].blockNumberOfRewardUpdate - start_time);
    }

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Only Owner Functions  //////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /**
     * @dev The function is used to upgrade the contract The addressed in stored a predetermined location to prevent any possible
     *      storage collision as per EIP1967 standard
     * @param newImplementation the address of the new implementation
     * @notice Only the owner can call this function
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev The function is used to update the reward per block
     * @param _rewardPerBlock the reward per block
     * @notice Only the owner can call this function
     */
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        Rewards storage rewards = s_rewards;
        rewards.rewards[rewards.updateCounter].rewarddata = _rewardPerBlock;
        rewards.rewards[rewards.updateCounter].blockNumberOfRewardUpdate = block.number;
        rewards.updateCounter++;
    }

    /**
     * @dev The function is used to update the unbonding period
     * @param _unbondingPeriod the unbonding period
     * @notice Only the owner can call this function
     */
    function setUnbondingPeriod(uint256 _unbondingPeriod) external onlyOwner {
        s_unbondingPeriod = _unbondingPeriod;
    }

    /**
     * @dev The function is used to update the reward claim delay
     * @param _rewardClaimDelay the reward claim delay
     * @notice Only the owner can call this function
     */
    function setRewardClaimDelay(uint256 _rewardClaimDelay) external onlyOwner {
        s_rewardClaimDelay = _rewardClaimDelay;
    }

    /**
     * @dev The function is used to update the reward token
     * @param _rewardToken the reward token
     * @notice Only the owner can call this function
     */
    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        s_rewardToken = RewardToken(address(_rewardToken));
    }

    /**
     * @dev This function is used to Pause the contract since it is upgreadable it is stored in a predetermined locaton to prevent
     *      any possible storage collsion with the new implementation
     * @notice Only the owner can call this function
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev This function is used to Unpause the contract
     * @notice Only the owner can call this function
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    ///////////////////////////////////////////////////////////////////////
    /////////////////  Getter Functions  /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /**
     * @dev The function is used to get the reward token
     * @return the address of the reward token
     */
    function getRewardToken() external view returns (address) {
        return address(s_rewardToken);
    }

    /**
     * @dev The function is used to get the NFT token thats accepted by the contract
     * @return the address of the NFT token
     */
    function getNftToken() external view returns (address) {
        return address(s_nftToken);
    }

    /**
     * @dev The function is used to get the reward per block
     * @return the reward per block
     */
    function getRewardPerBlockRecent() external view returns (uint256) {
        return s_rewards.rewards[s_rewards.updateCounter].rewarddata;
    }

    /**
     * @dev The function is used to get the unbonding period
     * @return the unbonding period
     */
    function getUnbondingPeriod() external view returns (uint256) {
        return s_unbondingPeriod;
    }

    /**
     * @dev The function is used to get the reward claim delay
     * @return the reward claim delay
     */
    function getRewardClaimDelay() external view returns (uint256) {
        return s_rewardClaimDelay;
    }

    /**
     * @dev The function is used to get the total number of tokens staked by a user
     * @param user the address of the user
     * @return the array of the token ids staked by the user
     */
    function getTokensStaked(address user) external view returns (uint256[] memory) {
        return stakes[user].tokenIds;
    }

    /**
     * @dev The function is used to get the total number of tokens staked by a user
     * @param user the address of the user
     * @return the array of the token ids staked by the user
     */
    function getTokenIfClaimed(address user, uint256 tokenId) external view returns (bool) {
        return stakes[user].stateData[tokenId].isWithdrawn;
    }

    /**
     * @dev The function is used to get the total number of tokens staked by a user
     * @param user the address of the user
     * @return the array of the token ids staked by the user
     */
    function getTokenIfUnbonding(address user, uint256 tokenId) external view returns (bool) {
        return stakes[user].stateData[tokenId].isUnbonding;
    }

    /**
     * @dev The function is used to get the total number of tokens staked by a user
     * @param user the address of the user
     * @return the array of the token ids staked by the user
     */
    function getStakeBlockNumberOfToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].DepositTime;
    }

    /**
     * @dev The function is used to get the total number of tokens staked by a user
     * @param user the address of the user
     * @return the array of the token ids staked by the user
     */
    function getWithdrawTimeOfSTakedToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].UnstakeTime;
    }

    function getUnbondingBlockNumberOfToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].unBondingBlockNumber;
    }

    function getCOunteOFUpdateOfReward() external view returns (uint256) {
        return s_rewards.updateCounter;
    }

    function getClaimRewardsOfUser(address user) external view returns (uint256) {
        return stakes[user].claimRewards;
    }

    function getClaimRewardBlockNumberOfToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].claimRewardBlockNumber;
    }

    function getRewardUpdateData(uint256 index) external view returns (uint256, uint256) {
        return (s_rewards.rewards[index].rewarddata, s_rewards.rewards[index].blockNumberOfRewardUpdate);
    }

    /**
     * @dev This is function is used to see how many times the rewards have been updated during the token stake period 
     * @param user The address of the user who staked the NFT 
     * @param tokenId The TokenID of the NFT
     */
    function getRewardCounterOfToken(address user, uint256 tokenId) external view returns (uint256[] memory temp) {
        uint256 length = s_rewards.updateCounter;

        uint256 tempval;
        uint256 count = 1;

        uint256[] memory rewardCounter = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            if (s_rewards.rewards[i].blockNumberOfRewardUpdate > stakes[user].stateData[tokenId].RewardTrackerBlock) {
                rewardCounter[count] = i;
                count++;
            }
        }
        temp = new uint256[](count);
        if (count == 1) {
            temp[0] = tempval;
        } else {
            temp[0] = count;
            for (uint256 i = 0; i < count; i++) {
                temp[i] = rewardCounter[i];
            }
        }
    }
}

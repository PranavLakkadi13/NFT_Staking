// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RewardToken.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTStaking is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    ///////////////////////////////////////////////////////////////////////
    /////////////////  State Variables  ///////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    RewardToken private s_rewardToken;
    IERC721 private s_nftToken;
    uint256 private s_rewardPerBlock;
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
    }
 
    struct Stake {
        uint256[] tokenIds;
        mapping(uint256  => data) stateData;
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
        s_rewardPerBlock = _rewardPerBlock;
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
    function withdrawNFTs(uint256[] calldata tokenIds) external {
        Stake storage userStake = stakes[msg.sender];

        if (tokenIds.length == 0) {
            revert NFTStaking__InvalidArraySize();
        }

        uint256 arrayLength = tokenIds.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            if (userStake.stateData[tokenIds[i]].isUnbonding == false) {
                revert NFTStaking__IncorrectTokenIdToWithdraw(tokenIds[i]);
            }

            if (userStake.stateData[tokenIds[i]].unBondingBlockNumber >= block.number) {
                revert NFTStaking__IncorrectTokenIdToWithdraw(tokenIds[i]);
            }

            s_nftToken.transferFrom(address(this), msg.sender, tokenIds[i]);
            userStake.claimRewards += _calculateReward(msg.sender, tokenIds[i]);
            userStake.stateData[tokenIds[i]].claimRewards = _calculateReward(msg.sender, tokenIds[i]);
            userStake.stateData[tokenIds[i]].claimRewardBlockNumber = block.number + s_rewardClaimDelay;
            userStake.stateData[tokenIds[i]].isWithdrawn = true;
            userStake.stateData[tokenIds[i]].isUnbonding = false;
            userStake.stateData[tokenIds[i]].unBondingBlockNumber = 0;
            userStake.stateData[tokenIds[i]].UnstakeTime = 0;
            userStake.stateData[tokenIds[i]].DepositTime = 0;

            emit WithdrawNFTs(msg.sender,tokenIds[i]);
        }
    }

    function claimRewards() external whenNotPaused {
        uint256 reward;
        Stake storage userStake = stakes[msg.sender];

        if (userStake.claimRewards == 0) {
            revert NFTStaking__NoRewardsToCliam();
        }

        uint256 arrayLength = userStake.tokenIds.length;
        
        for(uint256 i = 0; i < arrayLength; i++) {
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

    function _calculateReward(address user, uint256 tokenId) internal view returns (uint256 reward) {
        Stake storage userStake = stakes[user];
        
        uint256 endTime = userStake.stateData[tokenId].unBondingBlockNumber;
        uint256 startTime = userStake.stateData[tokenId].DepositTime;

        uint256 Duration = endTime - startTime;
        reward = Duration * s_rewardPerBlock;
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
        s_rewardPerBlock = _rewardPerBlock;
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
    function getRewardPerBlock() external view returns (uint256) {
        return s_rewardPerBlock;
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
}


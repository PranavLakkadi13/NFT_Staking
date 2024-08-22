// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTStaking is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    ///////////////////////////////////////////////////////////////////////
    /////////////////  State Variables  ///////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    IERC20 private s_rewardToken;
    IERC721 private s_nftToken;
    uint256 private s_rewardPerBlock;
    uint256 private s_unbondingPeriod;
    uint256 private s_rewardClaimDelay;

    struct data {
        bool isWithdrawn;
        bool isUnbonding;
        uint256 unBondingBlockNumber;
        uint256 withDrawnTime;
        uint256 DepositTime;
        uint256 claimableReward;
    }
 
    struct Stake {
        uint256[] tokenIds;
        mapping(uint256  => data) stateData;
    }

    mapping(address user_address => Stake) private stakes;


    ///////////////////////////////////////////////////////////////////////
    /////////////////  Errors   ///////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    error NFTStaking__IncorrectNFTToken();
    error NFTStaking__IncorrectTokenIdToStake();
    error NFTStaking__InvalidArraySize();
    error NFTStaking__AlreadyStaked();
    error NFTStaking__IncorrectTokenIdToWithdraw();


    ///////////////////////////////////////////////////////////////////////
    /////////////////  Events   ///////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////


    event Staked(address indexed user, uint256 tokenIds);
    event Unstaked(address indexed user, uint256 tokenIds);
    event RewardsClaimed(address indexed user, uint256 amount);



    ///////////////////////////////////////////////////////////////////////
    /////////////////  Constructor  ///////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function initialize(
        IERC20 _rewardToken,
        IERC721 _nftToken,
        uint256 _rewardPerBlock,
        uint256 _unbondingPeriod,
        uint256 _rewardClaimDelay
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();

        s_nftToken = _nftToken;
        s_rewardToken = _rewardToken;
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
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stake_single_token(nftContract, tokenIds[i]);
        }
    }


    /**
     * @dev The function is used to unstake a single token
     * @param tokenId the token id to unstake
     * @notice The user can only unstake the token only if the contract is not paused
     */
    function unstake_single_token(uint256 tokenId) public whenNotPaused {
        
        if (stakes[msg.sender].stateData[tokenId].DepositTime == 0) {
            revert NFTStaking__IncorrectTokenIdToWithdraw();
        }

        Stake storage userStake = stakes[msg.sender];

        userStake.stateData[tokenId].isUnbonding = true;
        userStake.stateData[tokenId].unBondingBlockNumber = block.number + s_unbondingPeriod;
        userStake.stateData[tokenId].withDrawnTime = block.number;

        emit Unstaked(msg.sender, tokenId);
    }

    function unstake_Multiple_Tokens(uint256[] memory tokenIds) external whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            unstake_single_token(tokenIds[i]);
        }
    }

    // function withdrawNFTs(address nftContract) external {
    //     Stake storage userStake = stakes[msg.sender][nftContract];
    //     require(userStake.isUnbonding, "Not in unbonding state");
    //     require(block.number >= userStake.stakedAt + s_unbondingPeriod, "Unbonding period not over");

    //     for (uint256 i = 0; i < userStake.tokenIds.length; i++) {
    //         IERC721(nftContract).transferFrom(address(this), msg.sender, userStake.tokenIds[i]);
    //     }
        
    //     delete stakes[msg.sender][nftContract];
    // }

    // function claimRewards(address nftContract) external whenNotPaused {
    //     uint256 reward = calculateReward(msg.sender, nftContract);
    //     require(reward > 0, "No rewards available");

    //     s_rewardToken.transfer(msg.sender, reward);

    //     Stake storage userStake = stakes[msg.sender][nftContract];
    //     userStake.lastClaimBlock = block.number;

    //     emit RewardsClaimed(msg.sender, reward);
    // }

    // function calculateReward(address user, address nftContract) public view returns (uint256) {
    //     Stake storage userStake = stakes[user][nftContract];
    //     uint256 blocksStaked = block.number - userStake.lastClaimBlock;
    //     uint256 reward = blocksStaked * s_rewardPerBlock * userStake.tokenIds.length;
    //     return reward;
    // }

    // function _removeTokenFromStake(uint256[] storage tokenIds, uint256 tokenId) internal {
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         if (tokenIds[i] == tokenId) {
    //             tokenIds[i] = tokenIds[tokenIds.length - 1];
    //             tokenIds.pop();
    //             break;
    //         }
    //     }
    // }


    ///////////////////////////////////////////////////////////////////////
    /////////////////  Only Owner Functions  //////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        s_rewardPerBlock = _rewardPerBlock;
    }

    function setUnbondingPeriod(uint256 _unbondingPeriod) external onlyOwner {
        s_unbondingPeriod = _unbondingPeriod;
    }

    function setRewardClaimDelay(uint256 _rewardClaimDelay) external onlyOwner {
        s_rewardClaimDelay = _rewardClaimDelay;
    }

    function setRewardToken(IERC20 _rewardToken) external onlyOwner {
        s_rewardToken = _rewardToken;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    ///////////////////////////////////////////////////////////////////////
    /////////////////  Getter Functions  /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function getRewardToken() external view returns (address) {
        return address(s_rewardToken);
    }

    function getNftToken() external view returns (address) {
        return address(s_nftToken);
    }

    function getRewardPerBlock() external view returns (uint256) {
        return s_rewardPerBlock;
    }

    function getUnbondingPeriod() external view returns (uint256) {
        return s_unbondingPeriod;
    }

    function getRewardClaimDelay() external view returns (uint256) {
        return s_rewardClaimDelay;
    }


    function getTokensStaked(address user) external view returns (uint256[] memory) {
        return stakes[user].tokenIds;
    }

    function getTokenIfClaimed(address user, uint256 tokenId) external view returns (bool) {
        return stakes[user].stateData[tokenId].isWithdrawn;
    }

    function getTokenIfUnbonding(address user, uint256 tokenId) external view returns (bool) {
        return stakes[user].stateData[tokenId].isUnbonding;
    }

    function getStakeBlockNumberOfToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].DepositTime;
    }

    function getWithdrawTimeOfSTakedToken(address user, uint256 tokenId) external view returns (uint256) {
        return stakes[user].stateData[tokenId].withDrawnTime;
    }
}


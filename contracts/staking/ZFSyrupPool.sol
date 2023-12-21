//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ZFSyrupPool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;

    uint256 public rewardPerSecond = 0.0165 ether;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    uint256 public lastRewardTime;
    uint256 public PRECISION_FACTOR = 1e12;
    uint256 public accTokenPerShare;
    
    address public stakedToken;
    address public rewardToken;
    // Event
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        address _stakedToken,
        address _rewardToken,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) {
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        
        lastRewardTime = startTimestamp;
    }

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTime) return;
        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardTime, block.timestamp);
        uint256 zfReward = multiplier.mul(rewardPerSecond);
        accTokenPerShare = accTokenPerShare.add(zfReward.mul(PRECISION_FACTOR).div(stakedTokenSupply));
        lastRewardTime = block.timestamp;
    }
    
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
            if (pending > 0) {
                IERC20(rewardToken).safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            IERC20(stakedToken).safeTransferFrom(address(msg.sender), address(this), _amount);
            // Update user 
            user.amount = user.amount.add(_amount);
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: Amount to withdraw too high");
        // Check harvest
       
        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
            if (pending > 0) {
                IERC20(rewardToken).safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            IERC20(stakedToken).safeTransfer(address(msg.sender), _amount);

        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);

        emit Withdraw(msg.sender, _amount);
    }
    
    function _getMultiplier(uint256 _from, uint256 _to) private view returns (uint256) {
        if (_to <= endTimestamp) {
            return _to.sub(_from);
        }
        else if (_from >= endTimestamp) return 0;
        else return endTimestamp.sub(_from);
    }

    function pendingReward(address _user) public view returns (uint256) {
        UserInfo memory user = userInfo[_user];

        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));
        if (block.timestamp > lastRewardTime && stakedTokenSupply > 0) {
            uint256 multiplier = _getMultiplier(lastRewardTime, block.timestamp);
            uint256 zfReward = multiplier.mul(rewardPerSecond);
            uint256 adjustedTokenPerShare = accTokenPerShare.add(zfReward.mul(PRECISION_FACTOR).div(stakedTokenSupply));
            return user.amount.mul(adjustedTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
        }
        else {
            return user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
        }

    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        startTimestamp = _startTime;
        lastRewardTime = startTimestamp;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTimestamp = _endTime;
    }
    function stopReward() external onlyOwner {
        endTimestamp = block.timestamp;
    }

    function setRewardRate(uint256 _rewardPerSecond) external onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    function emergencyRewardWithdraw(address _token, uint256 _amount) onlyOwner external {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
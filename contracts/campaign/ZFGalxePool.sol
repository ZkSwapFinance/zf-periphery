// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ZFGalxePool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 lastTimeAction;
    }

    uint256 constant MAX_LOCKED_TIME = 1703462400;

    address public lpToken;
    address[] public users;

    mapping(address => UserInfo) internal userInfo;
    uint256 public lockedEndTimestamp;
    uint256 public campaignEndTimestamp;

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);

    constructor(address _lpTokenAddress, uint256 _lockedEndTimestamp, uint256 _campaignEndTimestamp) {
        lpToken = _lpTokenAddress;
        lockedEndTimestamp = _lockedEndTimestamp;
        campaignEndTimestamp = _campaignEndTimestamp;
    }

    // Deposit LP token
    // Lock LP in lockedTime
    function deposit(uint256 _amount) public nonReentrant {
        require(block.timestamp <= campaignEndTimestamp, "deposit: Galxe Campaign Ended");
        require(_amount > 0, "deposit: _amount <= 0");

        UserInfo storage user = userInfo[msg.sender];

        // Transfer LP Token (no fee)
        IERC20(lpToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        if (user.amount == 0) users.push(msg.sender);
        // Update user amount
        user.amount = user.amount.add(_amount);
        user.lastTimeAction = block.timestamp;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw() public nonReentrant {
        require(block.timestamp >= lockedEndTimestamp, "withdraw: early");
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "withdraw: not yet deposited");

        IERC20(lpToken).safeTransfer(address(msg.sender), user.amount);

        user.amount = 0;
        // Update user info
        user.lastTimeAction = block.timestamp;

        emit Withdraw(msg.sender, user.amount);
    }

    function setGalxeTime(uint256 _lockedEndTime, uint256 _campaignEndTime) public onlyOwner {
        require(
            _lockedEndTime <= MAX_LOCKED_TIME,
            "setGalxeTime: _lockedEndTime > MAX_LOCKED_TIME"
        );
        lockedEndTimestamp = _lockedEndTime;
        campaignEndTimestamp = _campaignEndTime;
    }

    function getUserLength() public view returns (uint256) {
        return users.length;
    }

    function getUserInfo(address _user) public view returns (UserInfo memory) {
        return userInfo[_user];
    }
}

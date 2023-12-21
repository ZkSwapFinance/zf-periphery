//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ZFLaunchpad is Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public totalRaised;
    uint256 public totalRaisedBonus;
    uint256 public totalReferralAmount;
    uint256 public startTimestamp;
    uint256 public endTimestamp;

    address public depositToken;
    
    // Struct
    struct UserInfo {
        uint256 amount;
        uint256 amountBonus;
    }
    
    // UserInfo 
    mapping(address => UserInfo) private  userInfo;
    address[] public users;
    bool public isSaleStart;

    // Referral Info
    mapping(address => uint256) private referralInfo;
    address[] public referrals;

    // Event
    event Deposit(address indexed user, uint256 amount, address _referrer);

    constructor(
        address _depositToken,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) {
        depositToken = _depositToken;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;

        // Default 
        isSaleStart = true;
    }
    /**
     * CORE Function
     */

    function deposit(uint256 _amount, address _referrer) external nonReentrant {
        require(block.timestamp > startTimestamp, "deposit:Too early");
        require(block.timestamp < endTimestamp, "deposit:Too late");
        require(isSaleStart, "deposit: Sale not yet enabled");

        require(_amount > 0, "deposit:Amount must be > 0");

        UserInfo storage user = userInfo[msg.sender];
        // Transfer fund to this contract
        
        IERC20(depositToken).safeTransferFrom(address(msg.sender), address(this), _amount);

        if (user.amount == 0) users.push(msg.sender);
        // Set value before check discount
        totalRaised = totalRaised.add(_amount);
        user.amount = user.amount.add(_amount);

        // Check discount
        uint256 _bonusPercent = getBonusPercentage();
        // Update amount + bonus
        _amount = _amount + _amount.mul(_bonusPercent).div(100);
        // Update user 
        user.amountBonus = user.amountBonus.add(_amount);
        totalRaisedBonus = totalRaisedBonus.add(_amount);

        // Referral
        if (_referrer != address(0) && _referrer != msg.sender) {
            if (referralInfo[_referrer] == 0) referrals.push(_referrer);
            uint256 _referralAmount = _amount.mul(5).div(100);
            referralInfo[_referrer] = referralInfo[_referrer].add(_referralAmount);
            totalReferralAmount = totalReferralAmount.add(_referralAmount);
        }

        emit Deposit(msg.sender, _amount, _referrer);
    }

    function getBonusPercentage() public view returns (uint256) {
        // No discount
        if (block.timestamp < startTimestamp || block.timestamp.sub(startTimestamp).div(356400) > 0) { // No bonus
            return 0;
        }
        uint256 _currentTime = block.timestamp.sub(startTimestamp);
        // Zone 3
        if (_currentTime >= 32400 && _currentTime.sub(32400).div(324000) == 0){
            return 15 - (_currentTime.sub(32400)).div(21600);
        }

        return 25 - (_currentTime.div(10800)).mul(5) + (_currentTime.div(21600)).mul(5);
    }


    function getUserInfo(address _user) public view returns (UserInfo memory) {
        return userInfo[_user];
    }

    function getUserLength() public view returns (uint256) {
        return users.length;
    }

    function withdrawFunds() external onlyOwner {
        uint256 amount = IERC20(depositToken).balanceOf(address(this));
        IERC20(depositToken).safeTransfer(msg.sender, amount);
    }

    function getReferralInfo(address _user) public view returns (uint256) {
        return referralInfo[_user];
    }

    function getReferrerLength() public view returns (uint256) {
        return referrals.length;
    }


    function setTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        startTimestamp = _startTime;
        endTimestamp = _endTime;
    }

    function setTokenAddress(address _tokenAddress) external onlyOwner{
        depositToken = _tokenAddress;
    }

    function enableSaleStart() external onlyOwner {
        isSaleStart = true;
    }

    function disableSaleStart() external onlyOwner {
        isSaleStart = false;
    }
}
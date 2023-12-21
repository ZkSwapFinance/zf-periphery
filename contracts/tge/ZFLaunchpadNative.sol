//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ZFLaunchpadNative is Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public totalRaised;
    uint256 public totalRaisedBonus;
    uint256 public totalReferralAmount;
    uint256 public startTimestamp = 1692964800;
    uint256 public endTimestamp = 1693396800;
    
    // Struct
    struct UserInfo {
        uint256 amount;
        uint256 amountBonus;
    }
    
    // UserInfo 
    mapping(address => UserInfo) private  userInfo;
    address[] public users;
    // Referral Info
    mapping(address => uint256) private referralInfo;
    address[] public referrals;

    bool public isSaleStart = true;
    // Event
    event Deposit(address indexed user, uint256 amount, address _referrer);

    /**
     * CORE Function
     */

    function deposit(address _referrer) payable external nonReentrant {
        require(block.timestamp > startTimestamp, "deposit:Too early");
        require(block.timestamp < endTimestamp, "deposit:Too late");
        require(isSaleStart, "deposit: Sale not yet enabled");

        uint256 _amount = msg.value;

        require(_amount > 0, "deposit:Amount must be > 0");

        UserInfo storage user = userInfo[msg.sender];
        // Transfer fund to this contract
        
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

    function _safeTransferETH(address to, uint256 value) private {
        (bool success, ) = to.call{ value: value }("");
        require(success, "_safeTransferETH: failed");
    }

    function withdrawFunds() external onlyOwner {
        uint256 amount = address(this).balance;
        _safeTransferETH(msg.sender, amount);
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

    function getUserLength() public view returns (uint256 length) {
        return users.length;
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

    function enableSaleStart() external onlyOwner {
        isSaleStart = true;
    }

    function disableSaleStart() external onlyOwner {
        isSaleStart = false;
    }
}
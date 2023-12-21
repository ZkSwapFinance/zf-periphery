// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IZFToken.sol";

import "./yZFToken.sol";

contract ZFGovernanceStaking is yZFToken, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public lastRewardTime;
    address public token;

    uint256 public zfPerSecond = 0.572 ether;   

    uint256 public startTimestamp = 1697802542;
    uint256 public endTimestamp = 1707480000; 

    uint8 public withdrawFeeFactor = 99; // 1%
    uint8 public constant withdrawFeeFactorMax = 100;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _token)
        yZFToken()
    {
        token = _token;
        lastRewardTime = startTimestamp;
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }


    function getZFPricePerFullShare() public view returns (uint256) {
        if (totalSupply == 0) return 0;
        uint256 _pool = balance().add(pendingZF());
        return _pool.mul(1e18).div(totalSupply);
    }

    function getYZFPricePerFullShare() public view returns (uint256) {
        uint256 _pool = balance().add(pendingZF());
        return totalSupply.mul(1e18).div(_pool);
    }

    function getCurrentZF(address _user) public view returns (uint256) {
        return balanceOf(_user).mul(getZFPricePerFullShare()).div(1e18);
    }

    function getMultiplier(uint256 _from, uint256 _to) private pure returns (uint256) {
        if (_to <= _from) return 0;
        return _to.sub(_from);
    }

    function pendingZF() public view returns (uint256) {
        uint256 _currentTime = block.timestamp >= endTimestamp ? endTimestamp: block.timestamp;
        uint256 multiplier = getMultiplier(lastRewardTime, _currentTime);
        
        return zfPerSecond.mul(multiplier);
    }

    function deposit(uint256 _amount) nonReentrant public {
        _deposit(_amount);
    }

    function _deposit(uint256 _amount) internal {
        uint256 _pool = balance();
        // Harvest
        uint256 pending = pendingZF();
        if (pending > 0) {
            IZFToken(token).mint(address(this), pending);
            lastRewardTime = block.timestamp;
            _pool = balance();
        }

        uint256 shares = 0;
        if (totalSupply == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply)).div(_pool);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, shares);
    }


    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) nonReentrant public {
        // Harvest
        uint256 pending = pendingZF();
        if (pending > 0) {
            IZFToken(token).mint(address(this), pending);
            lastRewardTime = block.timestamp;
        }
        
        uint256 _withdrawAmount = (balance().mul(_shares)).div(totalSupply);
        _withdrawAmount = _withdrawAmount.mul(withdrawFeeFactor).div(withdrawFeeFactorMax);

        _burn(msg.sender, _shares);
        IERC20(token).safeTransfer(msg.sender, _withdrawAmount);
    }

    function setWithdrawFeeFactor(uint8 _factor) external onlyOwner {
        require(_factor < withdrawFeeFactorMax, "setWithdrawFeeFactor: max Factor");
        withdrawFeeFactor = _factor;
    }

    function setRewardRate(uint256 _zfPerSecond) external onlyOwner {
        zfPerSecond = _zfPerSecond;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        startTimestamp = _startTime;
        lastRewardTime = _startTime;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTimestamp = _endTime;
    }
}

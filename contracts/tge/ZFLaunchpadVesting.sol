//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ZFLaunchpadVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => uint256) public vestingInfo;

    address public token = 0x31C2c031fDc9d33e974f327Ab0d9883Eae06cA4A;
    // start time of vesting. timestamp in seconds
    uint256 public startTimestamp = 1693414800;
    uint256 public totalRaiseETH;
    uint256 constant public TOTAL_FOR_TGE = 25*1e7;

    event AddVesting(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    /// Add vesting info (execute by operator after combining multichain launchpad)
    function addVesting(
        address _user,
        uint256 _amount
        ) external onlyOwner {
        
        require(address(_user) != address(0), "addVesting: user is the zero address");
        require(_amount > 0, "addVesting: amount is 0");
        // Add to vesting info
        vestingInfo[_user] = vestingInfo[_user] + _amount.mul(TOTAL_FOR_TGE).mul(1e18).div(totalRaiseETH);

        emit AddVesting(_user, _amount);
    }

    
    /// Add vestings info (execute by operator after combining multichain launchpad)
    function addVestings(address[] memory _user, uint256[] memory _amount) external onlyOwner {
        for (uint i = 0; i < _user.length; i++) {
            vestingInfo[_user[i]] = vestingInfo[_user[i]] + _amount[i].mul(TOTAL_FOR_TGE).mul(1e18).div(totalRaiseETH);
        }
    }

    function removeVesting(address _user) external onlyOwner {
        delete vestingInfo[_user];
    }

    function claim() external nonReentrant {
        require(block.timestamp >= startTimestamp, "claim: early");
        uint256 userAmount = vestingInfo[msg.sender];

        require(userAmount > 0, "claim: the vesting is already completed");

        IERC20(token).safeTransfer(address(msg.sender), userAmount);
        vestingInfo[msg.sender] = 0;

        emit Claim(msg.sender, userAmount);
    }

    function setStartTime(uint256 _value) external onlyOwner {
        startTimestamp = _value;
    }

    function setTotalRaiseByETH(uint256 _value) external onlyOwner {
        totalRaiseETH = _value;
    }

}
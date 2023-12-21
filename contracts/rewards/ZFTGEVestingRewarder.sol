// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IZFToken.sol";


contract ZFTGEVestingRewarder is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Claimed(address account, uint256 amount);

    address public tokenAddress;
    bytes32 merkleRoot;

    mapping(address => uint256) public latestClaim;

    uint256 public totalReward;
    uint256 public startTimestamp = 1694260800;
    uint256 public endTimestamp = 1707480000; // startTime + 5 months

    uint256 public zfPerSecond = 3.858 ether;

    bool public isClaimEnabled = true;

    constructor(
        uint256 _totalReward,
        address _tokenAddress,
        bytes32 _merkleRoot
    ) {
        totalReward = _totalReward;
        tokenAddress = _tokenAddress;
        merkleRoot = _merkleRoot;
    }

    function claim(
        address _account,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        external nonReentrant
    {
        _claim(_account, _amount, _merkleProof);
    }


    function verifyClaim(
        address _account,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        public
        view
        returns (bool valid)
    {
        return _verifyClaim(_account, _amount, _merkleProof);
        
    }

    function _claim(
        address _account,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        private
    {
        require(isClaimEnabled, "_claim: claim not enabled");
        require(block.timestamp >= startTimestamp, "_claim: early");
        require(_amount > 0, "_claim: invalid amount");
        require(_verifyClaim(_account, _amount, _merkleProof), "_claim: Incorrect merkle proof");

        uint256 _amountClaimed = pendingZF(_account, _amount);

        require(_amountClaimed > 0, "_claim: pending amount = 0");

        IZFToken(tokenAddress).mint(_account, _amountClaimed);

        latestClaim[_account] = block.timestamp;
        emit Claimed(_account, _amountClaimed);
    }

    function _verifyClaim(
        address _account,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        private
        view
        returns (bool valid)
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }


    function getMultiplier(uint256 _from, uint256 _to) private pure returns (uint256) {
        if (_to <= _from) return 0;
        return _to.sub(_from);
    }

    function pendingZF(address _user, uint256 _amount) public view returns (uint256) {
        uint256 _currentTime = block.timestamp >= endTimestamp ? endTimestamp: block.timestamp;
        uint256 _lastClaimed = latestClaim[_user] == 0 ? startTimestamp : latestClaim[_user];
        uint256 multiplier = getMultiplier(_lastClaimed, _currentTime);
        
        return zfPerSecond.mul(multiplier).mul(_amount).div(totalReward);
    }
    
    // 
    // Set before adding vesting info
    function setStartTime(uint256 _startTime) external onlyOwner {
        startTimestamp = _startTime;
    }

    function setEndTime(uint256 _endTime) external onlyOwner {
        endTimestamp = _endTime;
    }

    function setMerkleRoot(bytes32 _merkleRoot)  external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setTotalReward(uint256 _totalReward) external onlyOwner {
        totalReward = _totalReward;
    }
    
    function setRewardRate(uint256 _zfPerSecond) external onlyOwner {
        zfPerSecond = _zfPerSecond;
    }

    function withdrawToken(address _token, uint256 _amount) onlyOwner external {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function enableClaim(bool isEnabled) external onlyOwner {
        isClaimEnabled = isEnabled;
    }
}
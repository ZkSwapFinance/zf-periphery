// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IZFToken.sol";

contract ZFSwap2EarnRewarder is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Claimed(uint256 cycle, address account, uint256 amount);

    address public token;

    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => mapping(address => bool)) public isClaimed;
    uint256 public cycles;

    bool public isClaimEnabled = true;

    constructor(
        address _token
    ) {
        token = _token;
    }

    function addCycle(bytes32 _merkleRoot, uint256 _totalAllocation) 
        external 
        onlyOwner 
        returns (uint256 cycleId) 
    {

        cycleId = cycles;
        merkleRoots[cycleId] = _merkleRoot;

        cycles = cycles.add(1);

        _mintReward(_totalAllocation);
    }

    function endCycle(uint256 _cycleId)
        external
        onlyOwner
    {
        merkleRoots[_cycleId] = bytes32(0);

    }

    function claim(
        address _account,
        uint256 _cycle,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        external nonReentrant
    {
        _claim(_account, _cycle, _amount, _merkleProof);
    }


    function verifyClaim(
        address _account,
        uint256 _cycle,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        public
        view
        returns (bool valid)
    {
        return _verifyClaim(_account, _cycle, _amount, _merkleProof);
        
    }

    function _claim(
        address _account,
        uint256 _cycle,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        private
    {
        require(isClaimEnabled, "_claim: claim disabled");
        require(_cycle < cycles, "_claim: invalid cycle");
        require(_amount > 0, "_claim: invalid amount");

        require(!isClaimed[_cycle][_account], "_claim: Reward has already claimed");
        require(_verifyClaim(_account, _cycle, _amount, _merkleProof), "_claim: Incorrect merkle proof");

        IERC20(token).safeTransfer(_account, _amount);
        isClaimed[_cycle][_account] = true;

        emit Claimed(_cycle, _account,  _amount);
    }


    function _verifyClaim(
        address _account,
        uint256 _cycle,
        uint256 _amount,
        bytes32[] memory _merkleProof
    )
        private
        view
        returns (bool valid)
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));
        return MerkleProof.verify(_merkleProof, merkleRoots[_cycle], leaf);

    }

    function _mintReward(uint256 _amount) private {
        IZFToken(token).mint(address(this), _amount);
    }

    function mintReward(uint256 _amount) onlyOwner external {
        _mintReward(_amount);
    }

    function editCycle(uint256 _cycleId, bytes32 _merkleRoot) 
        external 
        onlyOwner 
    {
        require(_cycleId < cycles, "editCycle: invalid cycleId");
        merkleRoots[_cycleId] = _merkleRoot;

    }

    function withdrawToken(address _token, uint256 _amount) onlyOwner external {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    
    function enableClaim(bool isEnabled) external onlyOwner {
        isClaimEnabled = isEnabled;
    }
}
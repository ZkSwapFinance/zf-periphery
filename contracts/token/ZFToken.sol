// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


// ZF token with Governance
contract ZFToken is ERC20('zkSwap Finance', 'ZF'), Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;

    // modifier for mint function
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    constructor() {
        addMinter(msg.sender);
    }

    function mint(address to, uint256 amount) public onlyMinter returns(bool) {
        _mint(to, amount);
        return true;
    }
    

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function addMinter(address account) public onlyOwner returns (bool) {
        require(account != address(0), "addMinter: account is the zero address");
        return EnumerableSet.add(_minters, account);
    }

    function removeMinter(address account) public onlyOwner returns (bool) {
        require(account != address(0), "removeMinter: account is the zero address");
        return EnumerableSet.remove(_minters, account);
    }

    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    function getMinter(uint256 index) public view returns (address){
        require(index <= getMinterLength() - 1, "getMinter: index out of bounds");
        return EnumerableSet.at(_minters, index);
    }

}

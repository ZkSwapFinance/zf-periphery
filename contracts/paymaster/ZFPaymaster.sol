// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IZFRouter.sol";

contract ZFPaymaster is IPaymaster, Ownable {

    address public router;
    uint256 public gasRefunded = 20;

    mapping(address => bool) public allowedTokenList;

    modifier onlyBootloader() {
        require(
            msg.sender == BOOTLOADER_FORMAL_ADDRESS,
            "Only bootloader can call this method"
        );
        // Continue execution if called from the bootloader.
        _;
    }

    constructor(
        address _erc20,
        address _router
    ) {
        require(_erc20 != address(0), "invalid erc20");
        allowedTokenList[_erc20] = true;
        require(_router != address(0), "invalid router");
        router = _router;
    }

    function validateAndPayForPaymasterTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    )
        external
        payable
        onlyBootloader
        returns (bytes4 magic, bytes memory context)
    {
        // By default we consider the transaction as accepted.
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        require(
            _transaction.paymasterInput.length >= 4,
            "The standard paymaster input must be at least 4 bytes long"
        );

        bytes4 paymasterInputSelector = bytes4(
            _transaction.paymasterInput[0:4]
        );

        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
            // While the transaction data consists of address, uint256 and bytes data,
            // the data is not needed for this paymaster
            (address token, , ) = abi.decode(
                _transaction.paymasterInput[4:],
                (address, uint256, bytes)
            );

            // Verify if token is the correct one
            require(allowedTokenList[token], "Invalid token for paying fee");

            // We verify that the user has provided enough allowance
            uint256 providedAllowance = IERC20(token).allowance(
                address(uint160(_transaction.from)),
                address(this)
            );
            
            // Note, that while the minimal amount of ETH needed is tx.gasPrice * tx.gasLimit,
            // neither paymaster nor account are allowed to access this context variable.
            uint256 requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;
            uint256 priceForPayingFees = getPriceForPayingFees(requiredETH, token);
            
            require(
                providedAllowance >= priceForPayingFees,
                "Min allowance too low"
            );

            try
                IERC20(token).transferFrom(address(uint160(_transaction.from)), address(this), priceForPayingFees)
            {} catch (bytes memory revertReason) {
                // If the revert reason is empty or represented by just a function selector,
                // we replace the error with a more user-friendly message
                if (revertReason.length <= 4) {
                    revert("Failed to transferFrom from users' account");
                } else {
                    assembly {
                        revert(add(0x20, revertReason), mload(revertReason))
                    }
                }
            }

            // The bootloader never returns any data, so it can safely be ignored here.
            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
                value: requiredETH
            }("");
            require(
                success,
                "Failed to transfer tx fee to the bootloader. Paymaster balance might not be enough."
            );
        } else {
            revert("Unsupported paymaster flow in paymasterParams.");
        }
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32,
        bytes32,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {
    }

    receive() external payable {}

    function getPriceForPayingFees(uint256 _requiredETH, address _allowedToken) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(IZFRouter(router).WETH());
        path[1] = address(_allowedToken);

        uint256 usedETH = _requiredETH * (100 - gasRefunded) / 100;
        return IZFRouter(router).getAmountsOut(usedETH, path)[1];
    }

    function withdrawFee(address _token, uint256 _value) external onlyOwner {

        address NATIVE_TOKEN = 0x000000000000000000000000000000000000800A;
        if (_token == NATIVE_TOKEN) {
            (bool success, ) = payable(msg.sender).call{ value: _value }("");
            require(success, "_safeTransferETH: failed");
        }
        else {
            IERC20(_token).transfer(msg.sender, _value);
        }
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "setRouter: invalid router");
        router = _router;
    }

    function setGasRefunded(uint256 _gasRefunded) external onlyOwner {
        require(_gasRefunded < 100, "setGasRefunded: invalid value");
        gasRefunded = _gasRefunded;
    }

    function setAllowedTokenList(address _allowedToken, bool _isAllowed) external onlyOwner {
        require(_allowedToken != address(0), "setAllowedTokenList: invalid address");
        
        bool isAllowed = allowedTokenList[_allowedToken];
        if (isAllowed != _isAllowed) {
            allowedTokenList[_allowedToken] = _isAllowed;
        }
    }
    
}

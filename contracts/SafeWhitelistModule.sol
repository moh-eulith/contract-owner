// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ISafe {
    enum Operation {
        Call,
        DelegateCall
    }

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation
    ) external returns (bool success, bytes memory returnData);
}

contract SafeWhitelistModule {
    /// @notice Safe that owns the assets
    ISafe public immutable safe;
    address public immutable exchange;

    /// @notice Address allowed to trigger approvals
    mapping(address => bool) public operators;
    mapping(address => bool) public whitelist;

    error OnlyOperator();
    error OnlySafe();
    error ApproveFailed();
    error DepositFailed();
    error WithdrawFailed();
    error NotWhitelisted();
    error TransferFailed();

    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event WhitelistAdded(address indexed whiteAddr);
    event WhitelistRemoved(address indexed whiteAddr);

    constructor(address _safe, address _exchange) {
        require(_safe != address(0));
        require(_exchange != address(0));

        safe = ISafe(_safe);
        exchange = _exchange;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], OnlyOperator());
        _;
    }

    /**
     * @notice Add an operator (must be called via Safe transaction)
     * function is idempotent (adding the same operator multiple times has no effect)
     */
    function addOperator(address newOperator) external {
        require(msg.sender == address(safe), OnlySafe());
        require(newOperator != address(0));
        operators[newOperator] = true;
        
        emit OperatorAdded(newOperator);
    }

    /**
     * @notice Remove an operator (must be called via Safe transaction)
     * function is idempotent (removing the same operator multiple times has no effect)
     */
    function removeOperator(address newOperator) external {
        require(msg.sender == address(safe), OnlySafe());
        require(newOperator != address(0));
        operators[newOperator] = false;
        
        emit OperatorRemoved(newOperator);
    }

    /**
     * @notice Add a whitelist (must be called via Safe transaction)
     * function is idempotent (adding the same whitelist multiple times has no effect)
     */
    function addWhitelist(address newWhitelist) external {
        require(msg.sender == address(safe), OnlySafe());
        require(newWhitelist != address(0));
        whitelist[newWhitelist] = true;
        
        emit WhitelistAdded(newWhitelist);
    }

    /**
     * @notice Remove a whitelist (must be called via Safe transaction)
     * function is idempotent (removing the same whitelist multiple times has no effect)
     */
    function removeWhitelist(address newWhitelist) external {
        require(msg.sender == address(safe), OnlySafe());
        require(newWhitelist != address(0));
        whitelist[newWhitelist] = false;
        
        emit WhitelistRemoved(newWhitelist);
    }

    /**
     * @notice Deposits tokens from the Safe to the exchange
     */
    function depositToExchange(address token, uint amount) external onlyOperator {
        approve(token, amount);
        deposit(token, amount);
    }

    /**
     * @notice withdraw tokens from the exchange to the destination address
     * destination address must either be the safe itself, or whitelisted
     */
    function withdrawTo(address token, uint amount, address destination) external onlyOperator {
        require (destination == address(safe) || whitelist[destination], NotWhitelisted());
        withdraw(token, amount);
        if (destination != address(safe)) {
            transferErc20(token, amount, destination);
        }
    }

    /**
     * @notice Approve ERC20 tokens from the Safe
     */
    function approve(address token, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("approve(address,uint256)")),
            exchange,
            amount
        );

        bool success = execViaSafe(token, data);
        if (!success) revert ApproveFailed();
    }

    /**
     * @notice Transfer ERC20 tokens from the Safe
     */
    function transferErc20(address token, uint256 amount, address dest) internal {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("transfer(address,uint256)")),
            dest,
            amount
        );

        bool success = execViaSafe(token, data);
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Deposit ERC20 tokens from the Safe to the exchange (after approval)
     */
    function deposit(address token, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("depositErc20(address,uint256)")),
            token,
            amount
        );

        bool success = execViaSafe(exchange, data);
        if (!success) revert DepositFailed();
    }

    /**
     * @notice Withdraw ERC20 tokens from the exchange to the safe
     */
    function withdraw(address token, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("withdrawErc20(address,uint256)")),
            token,
            amount
        );

        bool success = execViaSafe(exchange, data);
        if (!success) revert WithdrawFailed();
    }

    function execViaSafe(address to, bytes memory data) internal returns (bool) {
        (bool success, bytes memory returndata) = safe.execTransactionFromModuleReturnData(
            to,
            0,
            data,
            ISafe.Operation.Call
        );
        // Look for revert reason and bubble it up if present
        if (!success && returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        }
        return success;
    }
}

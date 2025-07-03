// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IPaymentStreamEvents {
    event StreamCreated(uint256 indexed streamId, address indexed sender, address indexed recipient, address token, uint256 amount, uint256 startTime, uint256 endTime);
    event Withdrawal(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamCancelled(uint256 indexed streamId, uint256 senderBalance, uint256 recipientBalance);
    event FeeUpdated(uint256 newFee);
    event FeeCollectorUpdated(address indexed newCollector);
}

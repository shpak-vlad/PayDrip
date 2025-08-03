// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PaymentStream.sol";
import "../src/PaymentStreamProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PaymentStreamTest is Test {
    PaymentStream public paymentStream;
    MockERC20 public token;
    
    address public owner;
    address public sender;
    address public recipient;

    function setUp() public {
        owner = address(this);
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        PaymentStream implementation = new PaymentStream();
        
        bytes memory initData = abi.encodeWithSelector(
            PaymentStream.initialize.selector
        );
        
        PaymentStreamProxy proxy = new PaymentStreamProxy(
            address(implementation),
            initData
        );
        
        paymentStream = PaymentStream(address(proxy));
        token = new MockERC20();
    }

    function testInitialization() public {
        assertEq(paymentStream.owner(), owner);
        assertEq(paymentStream.streamCounter(), 0);
        assertEq(paymentStream.platformFee(), 0);
        assertEq(paymentStream.totalStreamsCreated(), 0);
        assertEq(paymentStream.totalVolumeStreamed(), 0);
    }

    function testProxyUpgradeability() public {
        PaymentStream newImplementation = new PaymentStream();
        paymentStream.upgradeToAndCall(address(newImplementation), "");
    }

    function testSetPlatformFee() public {
        uint256 newFee = 100;
        paymentStream.setPlatformFee(newFee);
        assertEq(paymentStream.platformFee(), newFee);
    }

    function testSetPlatformFeeFailsIfTooHigh() public {
        uint256 tooHighFee = 1001;
        vm.expectRevert("Fee too high");
        paymentStream.setPlatformFee(tooHighFee);
    }

    function testSetFeeCollector() public {
        address newCollector = makeAddr("collector");
        paymentStream.setFeeCollector(newCollector);
        assertEq(paymentStream.feeCollector(), newCollector);
    }

    function testSetFeeCollectorFailsForZeroAddress() public {
        vm.expectRevert("Invalid collector");
        paymentStream.setFeeCollector(address(0));
    }

    function testOnlyOwnerCanSetFee() public {
        vm.prank(sender);
        vm.expectRevert();
        paymentStream.setPlatformFee(100);
    }

    function testOnlyOwnerCanSetFeeCollector() public {
        vm.prank(sender);
        vm.expectRevert();
        paymentStream.setFeeCollector(makeAddr("collector"));
    }

    function testCreateStream() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        uint256 streamId = paymentStream.createStream(
            recipient,
            address(token),
            amount,
            duration
        );
        vm.stopPrank();

        assertEq(streamId, 0);
        assertEq(paymentStream.streamCounter(), 1);
        assertEq(paymentStream.totalStreamsCreated(), 1);
        assertEq(paymentStream.totalVolumeStreamed(), amount);
    }

    function testCreateStreamFailsWithZeroRecipient() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        vm.expectRevert();
        paymentStream.createStream(
            address(0),
            address(token),
            amount,
            duration
        );
        vm.stopPrank();
    }

    function testCreateStreamFailsWithSelfAsRecipient() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        vm.expectRevert();
        paymentStream.createStream(
            sender,
            address(token),
            amount,
            duration
        );
        vm.stopPrank();
    }

    function testCreateStreamFailsWithZeroAmount() public {
        uint256 duration = 30 days;

        vm.startPrank(sender);
        vm.expectRevert();
        paymentStream.createStream(
            recipient,
            address(token),
            0,
            duration
        );
        vm.stopPrank();
    }

    function testCreateStreamFailsWithZeroDuration() public {
        uint256 amount = 1000 * 10**18;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        vm.expectRevert();
        paymentStream.createStream(
            recipient,
            address(token),
            amount,
            0
        );
        vm.stopPrank();
    }

    function testGetUserStreams() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount * 2);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount * 2);
        
        paymentStream.createStream(recipient, address(token), amount, duration);
        paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        uint256[] memory senderStreams = paymentStream.getUserStreams(sender);
        uint256[] memory recipientStreams = paymentStream.getUserStreams(recipient);

        assertEq(senderStreams.length, 2);
        assertEq(recipientStreams.length, 2);
    }

    function testWithdrawal() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.prank(recipient);
        uint256 withdrawn = paymentStream.withdraw(streamId);

        assertGt(withdrawn, 0);
        assertEq(token.balanceOf(recipient), withdrawn);
    }

    function testWithdrawalFailsIfNotRecipient() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.prank(sender);
        vm.expectRevert();
        paymentStream.withdraw(streamId);
    }

    function testCalculateWithdrawable() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        uint256 withdrawable = paymentStream.calculateWithdrawable(streamId);
        assertApproxEqRel(withdrawable, amount / 2, 0.01e18);
    }

    function testCancelStream() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        uint256 senderBalanceBefore = token.balanceOf(sender);
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.prank(sender);
        paymentStream.cancelStream(streamId);

        assertGt(token.balanceOf(sender), senderBalanceBefore);
        assertGt(token.balanceOf(recipient), recipientBalanceBefore);
    }

    function testTokenTransferValidation() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        uint256 contractBalanceBefore = token.balanceOf(address(paymentStream));
        paymentStream.createStream(recipient, address(token), amount, duration);
        uint256 contractBalanceAfter = token.balanceOf(address(paymentStream));
        
        vm.stopPrank();

        assertEq(contractBalanceAfter - contractBalanceBefore, amount);
    }

    function testMultipleTokenSupport() public {
        MockERC20 token2 = new MockERC20();
        
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        token2.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        token2.approve(address(paymentStream), amount);
        
        uint256 streamId1 = paymentStream.createStream(recipient, address(token), amount, duration);
        uint256 streamId2 = paymentStream.createStream(recipient, address(token2), amount, duration);
        
        vm.stopPrank();

        assertEq(streamId2, streamId1 + 1);
    }

    function testInvalidTokenAddress() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        vm.prank(sender);
        vm.expectRevert();
        paymentStream.createStream(recipient, address(0), amount, duration);
    }

    function testBatchStreamCreation() public {
        address[] memory recipients = new address[](3);
        recipients[0] = recipient;
        recipients[1] = makeAddr("recipient2");
        recipients[2] = makeAddr("recipient3");

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 * 10**18;
        amounts[1] = 2000 * 10**18;
        amounts[2] = 1500 * 10**18;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 30 days;
        durations[1] = 60 days;
        durations[2] = 45 days;

        uint256 totalAmount = amounts[0] + amounts[1] + amounts[2];
        token.mint(sender, totalAmount);

        vm.startPrank(sender);
        token.approve(address(paymentStream), totalAmount);
        
        uint256[] memory streamIds = paymentStream.createMultipleStreams(
            recipients,
            address(token),
            amounts,
            durations
        );
        vm.stopPrank();

        assertEq(streamIds.length, 3);
        assertEq(paymentStream.streamCounter(), 3);
    }

    function testBatchStreamCreationFailsWithMismatchedArrays() public {
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory durations = new uint256[](3);

        vm.prank(sender);
        vm.expectRevert();
        paymentStream.createMultipleStreams(recipients, address(token), amounts, durations);
    }

    function testBatchStreamCreationFailsWithTooManyStreams() public {
        address[] memory recipients = new address[](51);
        uint256[] memory amounts = new uint256[](51);
        uint256[] memory durations = new uint256[](51);

        vm.prank(sender);
        vm.expectRevert();
        paymentStream.createMultipleStreams(recipients, address(token), amounts, durations);
    }

    function testStreamCreatedEvent() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        
        vm.expectEmit(true, true, true, true);
        emit StreamCreated(0, sender, recipient, address(token), amount, block.timestamp, block.timestamp + duration);
        
        paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();
    }

    function testWithdrawalEvent() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.prank(recipient);
        vm.expectEmit(true, true, false, false);
        emit Withdrawal(streamId, recipient, 0);
        paymentStream.withdraw(streamId);
    }

    function testCancellationEvent() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStream), amount);
        uint256 streamId = paymentStream.createStream(recipient, address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.prank(sender);
        vm.expectEmit(true, false, false, false);
        emit StreamCancelled(streamId, 0, 0);
        paymentStream.cancelStream(streamId);
    }

    event StreamCreated(uint256 indexed streamId, address indexed sender, address indexed recipient, address token, uint256 amount, uint256 startTime, uint256 endTime);
    event Withdrawal(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamCancelled(uint256 indexed streamId, uint256 senderBalance, uint256 recipientBalance);
}

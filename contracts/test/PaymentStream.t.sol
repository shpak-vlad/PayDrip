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
}

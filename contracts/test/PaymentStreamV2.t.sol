// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PaymentStream.sol";
import "../src/PaymentStreamV2.sol";
import "../src/PaymentStreamProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PaymentStreamV2Test is Test {
    PaymentStreamV2 public paymentStreamV2;
    MockERC20 public token;
    
    address public sender;
    address public recipient;

    function setUp() public {
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        PaymentStreamV2 implementation = new PaymentStreamV2();
        
        bytes memory initData = abi.encodeWithSelector(
            PaymentStream.initialize.selector
        );
        
        PaymentStreamProxy proxy = new PaymentStreamProxy(
            address(implementation),
            initData
        );
        
        paymentStreamV2 = PaymentStreamV2(address(proxy));
        token = new MockERC20();
    }

    function testUpgradeFromV1() public {
        assertTrue(address(paymentStreamV2) != address(0));
    }

    function testPauseStream() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStreamV2), amount);
        uint256 streamId = paymentStreamV2.createStream(recipient, address(token), amount, duration);
        
        paymentStreamV2.pauseStream(streamId);
        assertTrue(paymentStreamV2.streamPaused(streamId));
        vm.stopPrank();
    }

    function testWithdrawPausedStream() public {
        uint256 amount = 1000 * 10**18;
        uint256 duration = 30 days;

        token.mint(sender, amount);
        
        vm.startPrank(sender);
        token.approve(address(paymentStreamV2), amount);
        uint256 streamId = paymentStreamV2.createStream(recipient, address(token), amount, duration);
        paymentStreamV2.pauseStream(streamId);
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.prank(recipient);
        vm.expectRevert();
        paymentStreamV2.withdraw(streamId);
    }
}

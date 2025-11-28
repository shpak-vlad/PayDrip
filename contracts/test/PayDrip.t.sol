// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PayDrip.sol";
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

contract PayDripTest is Test {
    PayDrip public payDrip;
    MockERC20 public token;

    address public sender = address(0x1);
    address public receiver = address(0x2);

    uint256 constant AMOUNT_PER_STEP = 100 * 10**18;
    uint256 constant TOTAL_STEPS = 10;
    uint256 constant INTERVAL = 1 days;

    function setUp() public {
        token = new MockERC20();

        PayDrip implementation = new PayDrip();
        bytes memory initData = abi.encodeWithSelector(
            PayDrip.initialize.selector
        );

        PaymentStreamProxy proxy = new PaymentStreamProxy(
            address(implementation),
            initData
        );

        payDrip = PayDrip(address(proxy));

        token.mint(sender, 10000 * 10**18);

        vm.prank(sender);
        token.approve(address(payDrip), type(uint256).max);
    }

    function testCreateDrip() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        assertEq(dripId, 0);

        (
            address _sender,
            address _receiver,
            address _token,
            uint256 _amountPerStep,
            uint256 _totalSteps,
            uint256 _currentStep,
            ,
            ,
            bool _active
        ) = payDrip.getDrip(dripId);

        assertEq(_sender, sender);
        assertEq(_receiver, receiver);
        assertEq(_token, address(token));
        assertEq(_amountPerStep, AMOUNT_PER_STEP);
        assertEq(_totalSteps, TOTAL_STEPS);
        assertEq(_currentStep, 0);
        assertTrue(_active);
    }

    function testExecuteFirstStep() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        uint256 balanceBefore = token.balanceOf(receiver);

        bool executed = payDrip.executeStep(dripId);
        assertTrue(executed);

        uint256 balanceAfter = token.balanceOf(receiver);
        assertEq(balanceAfter - balanceBefore, AMOUNT_PER_STEP);

        (, , , , , uint256 currentStep, , , ) = payDrip.getDrip(dripId);
        assertEq(currentStep, 1);
    }

    function testCannotExecuteStepBeforeInterval() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);

        bool executed = payDrip.executeStep(dripId);
        assertFalse(executed);
    }

    function testExecuteStepAfterInterval() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);

        vm.warp(block.timestamp + INTERVAL);

        uint256 balanceBefore = token.balanceOf(receiver);
        bool executed = payDrip.executeStep(dripId);
        assertTrue(executed);

        uint256 balanceAfter = token.balanceOf(receiver);
        assertEq(balanceAfter - balanceBefore, AMOUNT_PER_STEP);
    }

    function testCompleteDrip() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        for (uint256 i = 0; i < TOTAL_STEPS; i++) {
            if (i > 0) {
                vm.warp(block.timestamp + INTERVAL);
            }
            payDrip.executeStep(dripId);
        }

        (, , , , , , , , bool active) = payDrip.getDrip(dripId);
        assertFalse(active);

        assertEq(token.balanceOf(receiver), AMOUNT_PER_STEP * TOTAL_STEPS);
    }

    function testCancelDrip() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);
        vm.warp(block.timestamp + INTERVAL);
        payDrip.executeStep(dripId);

        uint256 senderBalanceBefore = token.balanceOf(sender);

        vm.prank(sender);
        payDrip.cancelDrip(dripId);

        uint256 senderBalanceAfter = token.balanceOf(sender);
        uint256 expectedRefund = AMOUNT_PER_STEP * (TOTAL_STEPS - 2);
        assertEq(senderBalanceAfter - senderBalanceBefore, expectedRefund);

        (, , , , , , , , bool active) = payDrip.getDrip(dripId);
        assertFalse(active);
    }

    function testFailCreateDripZeroAmount() public {
        vm.prank(sender);
        payDrip.createDrip(0, TOTAL_STEPS, INTERVAL, receiver, address(token));
    }

    function testFailCreateDripZeroSteps() public {
        vm.prank(sender);
        payDrip.createDrip(AMOUNT_PER_STEP, 0, INTERVAL, receiver, address(token));
    }

    function testFailCreateDripZeroInterval() public {
        vm.prank(sender);
        payDrip.createDrip(AMOUNT_PER_STEP, TOTAL_STEPS, 0, receiver, address(token));
    }

    function testFailCreateDripSameAddress() public {
        vm.prank(sender);
        payDrip.createDrip(AMOUNT_PER_STEP, TOTAL_STEPS, INTERVAL, sender, address(token));
    }
}

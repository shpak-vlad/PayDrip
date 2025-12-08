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

    function test_RevertWhen_CreateDripZeroAmount() public {
        vm.prank(sender);
        vm.expectRevert();
        payDrip.createDrip(0, TOTAL_STEPS, INTERVAL, receiver, address(token));
    }

    function test_RevertWhen_CreateDripZeroSteps() public {
        vm.prank(sender);
        vm.expectRevert();
        payDrip.createDrip(AMOUNT_PER_STEP, 0, INTERVAL, receiver, address(token));
    }

    function test_RevertWhen_CreateDripZeroInterval() public {
        vm.prank(sender);
        vm.expectRevert();
        payDrip.createDrip(AMOUNT_PER_STEP, TOTAL_STEPS, 0, receiver, address(token));
    }

    function test_RevertWhen_CreateDripSameAddress() public {
        vm.prank(sender);
        vm.expectRevert();
        payDrip.createDrip(AMOUNT_PER_STEP, TOTAL_STEPS, INTERVAL, sender, address(token));
    }

    function testSingleStepDrip() public {
        uint256 singleStep = 1;
        uint256 amount = 500 * 10**18;

        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            amount,
            singleStep,
            INTERVAL,
            receiver,
            address(token)
        );

        uint256 balanceBefore = token.balanceOf(receiver);
        bool executed = payDrip.executeStep(dripId);
        assertTrue(executed);

        uint256 balanceAfter = token.balanceOf(receiver);
        assertEq(balanceAfter - balanceBefore, amount);

        (, , , , , , , , bool active) = payDrip.getDrip(dripId);
        assertFalse(active);
    }

    function testMultipleRapidExecuteAttempts() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        bool first = payDrip.executeStep(dripId);
        assertTrue(first);

        bool second = payDrip.executeStep(dripId);
        assertFalse(second);

        bool third = payDrip.executeStep(dripId);
        assertFalse(third);

        (, , , , , uint256 currentStep, , , ) = payDrip.getDrip(dripId);
        assertEq(currentStep, 1);
    }

    function testExactFundAccountingFullLifecycle() public {
        uint256 totalAmount = AMOUNT_PER_STEP * TOTAL_STEPS;
        uint256 contractBalanceBefore = token.balanceOf(address(payDrip));

        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        uint256 contractBalanceAfterCreate = token.balanceOf(address(payDrip));
        assertEq(contractBalanceAfterCreate - contractBalanceBefore, totalAmount);

        uint256 receiverBalance = 0;
        for (uint256 i = 0; i < TOTAL_STEPS; i++) {
            if (i > 0) {
                vm.warp(block.timestamp + INTERVAL);
            }
            payDrip.executeStep(dripId);
            receiverBalance += AMOUNT_PER_STEP;
        }

        assertEq(token.balanceOf(receiver), receiverBalance);
        assertEq(token.balanceOf(address(payDrip)), contractBalanceBefore);
    }

    function testVeryShortInterval() public {
        uint256 shortInterval = 1;

        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            3,
            shortInterval,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);

        vm.warp(block.timestamp + shortInterval);
        bool executed = payDrip.executeStep(dripId);
        assertTrue(executed);
    }

    function testVeryLongInterval() public {
        uint256 longInterval = 365 days * 10;

        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            2,
            longInterval,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);

        vm.warp(block.timestamp + longInterval - 1);
        bool notYet = payDrip.executeStep(dripId);
        assertFalse(notYet);

        vm.warp(block.timestamp + 1);
        bool executed = payDrip.executeStep(dripId);
        assertTrue(executed);
    }

    function testExactIntervalBoundary() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            3,
            INTERVAL,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);
        uint256 executionTime = block.timestamp;

        vm.warp(executionTime + INTERVAL - 1);
        bool tooEarly = payDrip.executeStep(dripId);
        assertFalse(tooEarly);

        vm.warp(executionTime + INTERVAL);
        bool exact = payDrip.executeStep(dripId);
        assertTrue(exact);
    }

    function test_RevertWhen_ExecuteCompletedDrip() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            2,
            INTERVAL,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId);
        vm.warp(block.timestamp + INTERVAL);
        payDrip.executeStep(dripId);

        vm.expectRevert();
        payDrip.executeStep(dripId);
    }

    function testCancelBeforeFirstStep() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        uint256 senderBalanceBefore = token.balanceOf(sender);

        vm.prank(sender);
        payDrip.cancelDrip(dripId);

        uint256 senderBalanceAfter = token.balanceOf(sender);
        assertEq(senderBalanceAfter - senderBalanceBefore, AMOUNT_PER_STEP * TOTAL_STEPS);

        (, , , , , , , , bool active) = payDrip.getDrip(dripId);
        assertFalse(active);
    }

    function test_RevertWhen_CancelAlreadyCancelledDrip() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        vm.prank(sender);
        payDrip.cancelDrip(dripId);

        vm.prank(sender);
        vm.expectRevert();
        payDrip.cancelDrip(dripId);
    }

    function test_RevertWhen_CancelByNonSender() public {
        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            receiver,
            address(token)
        );

        vm.prank(receiver);
        vm.expectRevert();
        payDrip.cancelDrip(dripId);
    }

    function testVariableAmountsExactAccounting() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 10**18;
        amounts[1] = 250 * 10**18;
        amounts[2] = 500 * 10**18;

        uint256 receiverStartBalance = token.balanceOf(receiver);

        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(sender);
            uint256 dripId = payDrip.createDrip(
                amounts[i],
                2,
                INTERVAL,
                receiver,
                address(token)
            );

            payDrip.executeStep(dripId);
            vm.warp(block.timestamp + INTERVAL);
            payDrip.executeStep(dripId);
        }

        uint256 expectedTotal = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            expectedTotal += amounts[i] * 2;
        }

        assertEq(token.balanceOf(receiver) - receiverStartBalance, expectedTotal);
    }

    function testLargeValuesWithinLimits() public {
        uint256 largeAmount = uint256(type(uint96).max) / 100;
        uint256 largeSteps = 100;
        uint256 largeInterval = 30 days;

        vm.prank(sender);
        token.mint(sender, largeAmount * largeSteps);

        vm.prank(sender);
        uint256 dripId = payDrip.createDrip(
            largeAmount,
            largeSteps,
            largeInterval,
            receiver,
            address(token)
        );

        (, , , uint256 storedAmount, uint256 storedSteps, , uint256 storedInterval, , ) = payDrip.getDrip(dripId);
        assertEq(storedAmount, largeAmount);
        assertEq(storedSteps, largeSteps);
        assertEq(storedInterval, largeInterval);
    }

    function testMultipleDripsIndependentExecution() public {
        vm.prank(sender);
        uint256 dripId1 = payDrip.createDrip(
            AMOUNT_PER_STEP,
            3,
            INTERVAL,
            receiver,
            address(token)
        );

        vm.prank(sender);
        uint256 dripId2 = payDrip.createDrip(
            AMOUNT_PER_STEP * 2,
            2,
            INTERVAL / 2,
            receiver,
            address(token)
        );

        payDrip.executeStep(dripId1);
        payDrip.executeStep(dripId2);

        vm.warp(block.timestamp + INTERVAL / 2);

        bool drip1Result = payDrip.executeStep(dripId1);
        assertFalse(drip1Result);

        bool drip2Result = payDrip.executeStep(dripId2);
        assertTrue(drip2Result);

        (, , , , , uint256 step1, , , ) = payDrip.getDrip(dripId1);
        (, , , , , uint256 step2, , , ) = payDrip.getDrip(dripId2);

        assertEq(step1, 1);
        assertEq(step2, 2);
    }
}

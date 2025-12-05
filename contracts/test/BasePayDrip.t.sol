// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PayDrip.sol";
import "../src/PaymentStreamProxy.sol";
import "../src/integrations/BasePayDrip.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**6);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract BasePayDripTest is Test {
    PayDrip public payDrip;
    BasePayDrip public basePayDrip;
    MockERC20 public usdc;

    address public oracle = address(0x3);
    address public basePayProcessor = address(0x4);
    address public sender = address(0x1);
    address public receiver = address(0x2);

    uint256 constant AMOUNT_PER_STEP = 100 * 10**6; // 100 USDC
    uint256 constant TOTAL_STEPS = 10;
    uint256 constant INTERVAL = 1 days;

    event DripPaymentInitiated(
        bytes32 indexed paymentId,
        address indexed sender,
        address indexed receiver,
        uint256 totalAmount,
        string checkoutUrl
    );

    event DripPaymentConfirmed(
        bytes32 indexed paymentId,
        uint256 indexed dripId
    );

    event DripPaymentFailed(
        bytes32 indexed paymentId,
        string reason
    );

    function setUp() public {
        usdc = new MockERC20();

        // Deploy PayDrip
        PayDrip payDripImpl = new PayDrip();
        bytes memory payDripInitData = abi.encodeWithSelector(
            PayDrip.initialize.selector
        );
        PaymentStreamProxy payDripProxy = new PaymentStreamProxy(
            address(payDripImpl),
            payDripInitData
        );
        payDrip = PayDrip(address(payDripProxy));

        // Deploy BasePayDrip
        BasePayDrip basePayDripImpl = new BasePayDrip();
        bytes memory basePayDripInitData = abi.encodeWithSelector(
            BasePayDrip.initialize.selector,
            address(payDrip),
            oracle,
            basePayProcessor
        );
        PaymentStreamProxy basePayDripProxy = new PaymentStreamProxy(
            address(basePayDripImpl),
            basePayDripInitData
        );
        basePayDrip = BasePayDrip(address(basePayDripProxy));

        // Mint tokens
        usdc.mint(sender, 10000 * 10**6);
        usdc.mint(address(basePayDrip), 10000 * 10**6);

        // Approve
        vm.prank(sender);
        usdc.approve(address(basePayDrip), type(uint256).max);
    }

    function testInitiateDripWithFiat() public {
        vm.prank(sender);
        (bytes32 paymentId, string memory checkoutUrl) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        assertTrue(paymentId != bytes32(0));
        assertTrue(bytes(checkoutUrl).length > 0);

        BasePayDrip.PendingDrip memory pending = basePayDrip.getPendingDrip(paymentId);
        assertEq(pending.sender, sender);
        assertEq(pending.receiver, receiver);
        assertEq(pending.amountPerStep, AMOUNT_PER_STEP);
        assertEq(pending.totalSteps, TOTAL_STEPS);
        assertEq(pending.interval, INTERVAL);
        assertTrue(pending.status == BasePayDrip.PaymentStatus.Pending);
    }

    function testConfirmPayment() public {
        vm.prank(sender);
        (bytes32 paymentId, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        vm.prank(oracle);
        basePayDrip.confirmPayment(paymentId, address(usdc));

        BasePayDrip.PendingDrip memory pending = basePayDrip.getPendingDrip(paymentId);
        assertTrue(pending.status == BasePayDrip.PaymentStatus.Confirmed);
        assertEq(pending.token, address(usdc));
    }

    function testFailConfirmPaymentUnauthorized() public {
        vm.prank(sender);
        (bytes32 paymentId, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        // Should fail - sender is not oracle
        vm.prank(sender);
        basePayDrip.confirmPayment(paymentId, address(usdc));
    }

    function testFailPayment() public {
        vm.prank(sender);
        (bytes32 paymentId, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        vm.prank(oracle);
        basePayDrip.failPayment(paymentId, "Insufficient funds");

        BasePayDrip.PendingDrip memory pending = basePayDrip.getPendingDrip(paymentId);
        assertTrue(pending.status == BasePayDrip.PaymentStatus.Failed);
    }

    function testFinalizeDrip() public {
        vm.prank(sender);
        (bytes32 paymentId, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        vm.prank(oracle);
        basePayDrip.confirmPayment(paymentId, address(usdc));

        vm.prank(sender);
        uint256 dripId = basePayDrip.finalizeDrip(paymentId);

        assertTrue(dripId == 0); // First drip

        BasePayDrip.PendingDrip memory pending = basePayDrip.getPendingDrip(paymentId);
        assertEq(pending.dripId, dripId);

        // Verify drip was created in PayDrip contract
        (
            address _sender,
            address _receiver,
            address _token,
            uint256 _amountPerStep,
            uint256 _totalSteps,
            ,
            ,
            ,
            bool _active
        ) = payDrip.getDrip(dripId);

        assertEq(_sender, address(basePayDrip));
        assertEq(_receiver, receiver);
        assertEq(_token, address(usdc));
        assertEq(_amountPerStep, AMOUNT_PER_STEP);
        assertEq(_totalSteps, TOTAL_STEPS);
        assertTrue(_active);
    }

    function testGetUserPendingDrips() public {
        vm.prank(sender);
        (bytes32 paymentId1, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        vm.prank(sender);
        (bytes32 paymentId2, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP * 2,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        bytes32[] memory pendingDrips = basePayDrip.getUserPendingDrips(sender);
        assertEq(pendingDrips.length, 2);
        assertEq(pendingDrips[0], paymentId1);
        assertEq(pendingDrips[1], paymentId2);
    }

    function testFailFinalizeDripNotConfirmed() public {
        vm.prank(sender);
        (bytes32 paymentId, ) = basePayDrip.initiateDripWithFiat(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );

        // Should fail - payment not confirmed
        vm.prank(sender);
        basePayDrip.finalizeDrip(paymentId);
    }

    function testFailInitiateDripZeroAmount() public {
        vm.prank(sender);
        basePayDrip.initiateDripWithFiat(
            receiver,
            0,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );
    }

    function testFailInitiateDripSameAddress() public {
        vm.prank(sender);
        basePayDrip.initiateDripWithFiat(
            sender,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            "https://example.com/return"
        );
    }

    function testSetOracle() public {
        address newOracle = address(0x5);

        basePayDrip.setOracle(newOracle);
        assertEq(basePayDrip.oracle(), newOracle);
    }

    function testSetBasePayProcessor() public {
        address newProcessor = address(0x6);

        basePayDrip.setBasePayProcessor(newProcessor);
        assertEq(basePayDrip.basePayProcessor(), newProcessor);
    }
}

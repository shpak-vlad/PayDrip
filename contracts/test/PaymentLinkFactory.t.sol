// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/PayDrip.sol";
import "../src/PaymentStreamProxy.sol";
import "../src/integrations/BasePayDrip.sol";
import "../src/integrations/PaymentLinkFactory.sol";
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

contract PaymentLinkFactoryTest is Test {
    PayDrip public payDrip;
    BasePayDrip public basePayDrip;
    PaymentLinkFactory public linkFactory;
    MockERC20 public usdc;

    address public oracle = address(0x3);
    address public basePayProcessor = address(0x4);
    address public creator = address(0x1);
    address public receiver = address(0x2);
    address public payer = address(0x5);

    uint256 constant AMOUNT_PER_STEP = 100 * 10**6; // 100 USDC
    uint256 constant TOTAL_STEPS = 10;
    uint256 constant INTERVAL = 1 days;

    event LinkCreated(
        bytes32 indexed linkId,
        address indexed creator,
        address indexed receiver,
        uint256 totalAmount,
        uint256 expiry,
        bool multiUse
    );

    event LinkUsed(
        bytes32 indexed linkId,
        address indexed payer,
        uint256 indexed dripId,
        bool viaFiat
    );

    event LinkCancelled(
        bytes32 indexed linkId,
        address indexed creator
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

        // Deploy PaymentLinkFactory
        PaymentLinkFactory linkFactoryImpl = new PaymentLinkFactory();
        bytes memory linkFactoryInitData = abi.encodeWithSelector(
            PaymentLinkFactory.initialize.selector,
            address(payDrip),
            address(basePayDrip)
        );
        PaymentStreamProxy linkFactoryProxy = new PaymentStreamProxy(
            address(linkFactoryImpl),
            linkFactoryInitData
        );
        linkFactory = PaymentLinkFactory(address(linkFactoryProxy));

        // Mint tokens
        usdc.mint(creator, 10000 * 10**6);
        usdc.mint(payer, 10000 * 10**6);

        // Approve
        vm.prank(payer);
        usdc.approve(address(linkFactory), type(uint256).max);
    }

    function testCreatePaymentLink() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Test payment link",
            address(usdc),
            false
        );

        assertTrue(linkId != bytes32(0));

        PaymentLinkFactory.PaymentLink memory link = linkFactory.getLinkInfo(linkId);
        assertEq(link.creator, creator);
        assertEq(link.receiver, receiver);
        assertEq(link.amountPerStep, AMOUNT_PER_STEP);
        assertEq(link.totalSteps, TOTAL_STEPS);
        assertEq(link.interval, INTERVAL);
        assertEq(link.expiry, expiry);
        assertFalse(link.used);
        assertFalse(link.multiUse);
        assertEq(link.memo, "Test payment link");
        assertEq(link.token, address(usdc));
    }

    function testCreateMultiUseLink() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Multi-use link",
            address(usdc),
            true
        );

        PaymentLinkFactory.PaymentLink memory link = linkFactory.getLinkInfo(linkId);
        assertTrue(link.multiUse);
    }

    function testPayViaLink() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Test payment",
            address(usdc),
            false
        );

        vm.prank(payer);
        uint256 dripId = linkFactory.payViaLink(linkId);

        assertTrue(dripId == 0); // First drip

        PaymentLinkFactory.PaymentLink memory link = linkFactory.getLinkInfo(linkId);
        assertTrue(link.used);
        assertEq(link.usageCount, 1);

        // Verify drip created
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

        assertEq(_sender, address(linkFactory));
        assertEq(_receiver, receiver);
        assertEq(_token, address(usdc));
        assertEq(_amountPerStep, AMOUNT_PER_STEP);
        assertEq(_totalSteps, TOTAL_STEPS);
        assertTrue(_active);
    }

    function testPayViaMultiUseLink() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Multi-use payment",
            address(usdc),
            true
        );

        // First payment
        vm.prank(payer);
        linkFactory.payViaLink(linkId);

        // Second payment - should work for multi-use
        vm.prank(payer);
        uint256 dripId2 = linkFactory.payViaLink(linkId);

        assertTrue(dripId2 == 1); // Second drip

        PaymentLinkFactory.PaymentLink memory link = linkFactory.getLinkInfo(linkId);
        assertFalse(link.used); // Still not marked as used for multi-use
        assertEq(link.usageCount, 2);
    }

    function test_RevertWhen_PayViaSingleUseLinkTwice() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Single use",
            address(usdc),
            false
        );

        vm.prank(payer);
        linkFactory.payViaLink(linkId);

        // Second payment should fail
        vm.prank(payer);
        vm.expectRevert();
        linkFactory.payViaLink(linkId);
    }

    function testCancelLink() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Test payment",
            address(usdc),
            false
        );

        vm.prank(creator);
        linkFactory.cancelLink(linkId);

        PaymentLinkFactory.PaymentLink memory link = linkFactory.getLinkInfo(linkId);
        assertTrue(link.used);
        assertTrue(link.expiry <= block.timestamp);
    }

    function test_RevertWhen_CancelLinkUnauthorized() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Test payment",
            address(usdc),
            false
        );

        // Should fail - payer is not creator
        vm.prank(payer);
        vm.expectRevert();
        linkFactory.cancelLink(linkId);
    }

    function testIsLinkValid() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Test payment",
            address(usdc),
            false
        );

        assertTrue(linkFactory.isLinkValid(linkId));

        // Use the link
        vm.prank(payer);
        linkFactory.payViaLink(linkId);

        // Should be invalid after use
        assertFalse(linkFactory.isLinkValid(linkId));
    }

    function testLinkExpiry() public {
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Expiring link",
            address(usdc),
            false
        );

        assertTrue(linkFactory.isLinkValid(linkId));

        // Warp past expiry
        vm.warp(block.timestamp + 2 hours);

        assertFalse(linkFactory.isLinkValid(linkId));
    }

    function testGetUserLinks() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId1 = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Link 1",
            address(usdc),
            false
        );

        vm.prank(creator);
        bytes32 linkId2 = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP * 2,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Link 2",
            address(usdc),
            false
        );

        bytes32[] memory userLinks = linkFactory.getUserLinks(creator);
        assertEq(userLinks.length, 2);
        assertEq(userLinks[0], linkId1);
        assertEq(userLinks[1], linkId2);
    }

    function testGetLinkDrips() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(creator);
        bytes32 linkId = linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            expiry,
            "Multi-use",
            address(usdc),
            true
        );

        vm.prank(payer);
        uint256 dripId1 = linkFactory.payViaLink(linkId);

        vm.prank(payer);
        uint256 dripId2 = linkFactory.payViaLink(linkId);

        uint256[] memory linkDrips = linkFactory.getLinkDrips(linkId);
        assertEq(linkDrips.length, 2);
        assertEq(linkDrips[0], dripId1);
        assertEq(linkDrips[1], dripId2);
    }

    function test_RevertWhen_CreateLinkZeroAmount() public {
        vm.prank(creator);
        vm.expectRevert();
        linkFactory.createPaymentLink(
            receiver,
            0,
            TOTAL_STEPS,
            INTERVAL,
            block.timestamp + 7 days,
            "Test",
            address(usdc),
            false
        );
    }

    function test_RevertWhen_CreateLinkExpiredTime() public {
        vm.prank(creator);
        vm.expectRevert();
        linkFactory.createPaymentLink(
            receiver,
            AMOUNT_PER_STEP,
            TOTAL_STEPS,
            INTERVAL,
            block.timestamp - 1,
            "Test",
            address(usdc),
            false
        );
    }
}

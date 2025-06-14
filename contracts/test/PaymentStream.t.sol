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
    }

    function testProxyUpgradeability() public {
        PaymentStream newImplementation = new PaymentStream();
        paymentStream.upgradeToAndCall(address(newImplementation), "");
    }
}

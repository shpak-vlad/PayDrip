// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/AccessTiers.sol";

contract AccessTiersTest is Test {
    AccessTiers public accessTiers;
    
    function setUp() public {
        accessTiers = new AccessTiers();
    }
    
    function testSetTier() public {
        accessTiers.setTier(address(1), AccessTiers.Tier.Premium);
        assertEq(uint(accessTiers.userTiers(address(1))), uint(AccessTiers.Tier.Premium));
    }
}

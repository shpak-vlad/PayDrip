// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library MathLib {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256) {
        require(denominator > 0, "Division by zero");
        return (a * b) / denominator;
    }

    function percentageOf(uint256 amount, uint256 percentage, uint256 denominator) internal pure returns (uint256) {
        require(denominator > 0, "Invalid denominator");
        return (amount * percentage) / denominator;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IFiatQuoter
 * @notice Interface for FiatQuoter contract
 */
interface IFiatQuoter {
    struct Quote {
        uint256 fiatAmount;
        uint256 cryptoAmount;
        uint256 rate;
        uint256 validUntil;
        string fiatCurrency;
        address cryptoToken;
    }

    struct ExchangeRate {
        uint256 rate;
        uint256 lastUpdated;
        uint256 validityPeriod;
        bool active;
    }

    event RateUpdated(
        string indexed currency,
        uint256 rate,
        uint256 timestamp
    );

    event QuoteGenerated(
        address indexed requester,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string fiatCurrency,
        uint256 validUntil
    );

    function getQuote(uint256 usdcAmount, string calldata fiatCurrency)
        external
        view
        returns (uint256 fiatAmount, uint256 validUntil);

    function estimateDripCost(
        uint256 amountPerStep,
        uint256 totalSteps,
        string calldata fiatCurrency
    ) external view returns (uint256 fiatAmount);

    function getDetailedQuote(uint256 usdcAmount, string calldata fiatCurrency)
        external
        view
        returns (Quote memory quote);

    function updateRate(string calldata currency, uint256 newRate) external;

    function batchUpdateRates(
        string[] calldata currencies,
        uint256[] calldata rates
    ) external;

    function getRate(string calldata currency)
        external
        view
        returns (uint256 rate, uint256 lastUpdated);

    function isRateStale(string calldata currency) external view returns (bool);
}

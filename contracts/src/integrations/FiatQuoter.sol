// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title FiatQuoter
 * @notice Provides real-time fiat to crypto conversion quotes
 * @dev Uses oracle for price feeds and supports multiple fiat currencies
 */
contract FiatQuoter is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
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

    address public oracle;
    mapping(string => ExchangeRate) public exchangeRates;
    mapping(string => bool) public supportedCurrencies;

    uint256 public constant QUOTE_VALIDITY = 5 minutes;
    uint256 public constant RATE_DECIMALS = 6; // 6 decimals for rates (e.g., 1.000000 USD = 1 USDC)
    uint256 public constant FEE_BPS = 50; // 0.5% fee in basis points

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

    event CurrencyAdded(string currency);
    event CurrencyRemoved(string currency);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    error InvalidAmount();
    error InvalidCurrency();
    error UnsupportedCurrency();
    error StaleRate();
    error Unauthorized();

    modifier onlyOracle() {
        if (msg.sender != oracle) revert Unauthorized();
        _;
    }

    function initialize(address _oracle) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        oracle = _oracle;

        // Initialize default currencies
        _addCurrency("USD");
        _addCurrency("EUR");
        _addCurrency("GBP");

        // Set initial rates (1:1 for USDC, will be updated by oracle)
        exchangeRates["USD"] = ExchangeRate({
            rate: 1_000000, // 1 USDC = 1 USD
            lastUpdated: block.timestamp,
            validityPeriod: 1 hours,
            active: true
        });
    }

    /**
     * @notice Get quote for converting crypto to fiat
     * @param usdcAmount Amount in USDC (6 decimals)
     * @param fiatCurrency Target fiat currency code
     * @return fiatAmount Amount in fiat
     * @return validUntil Quote expiration timestamp
     */
    function getQuote(uint256 usdcAmount, string calldata fiatCurrency)
        external
        view
        returns (uint256 fiatAmount, uint256 validUntil)
    {
        if (usdcAmount == 0) revert InvalidAmount();
        if (!supportedCurrencies[fiatCurrency]) revert UnsupportedCurrency();

        ExchangeRate memory rate = exchangeRates[fiatCurrency];

        if (!rate.active) revert UnsupportedCurrency();
        if (block.timestamp > rate.lastUpdated + rate.validityPeriod) {
            revert StaleRate();
        }

        // Calculate fiat amount with fee
        // fiatAmount = (usdcAmount * rate * (10000 + FEE_BPS)) / (10^6 * 10000)
        uint256 amountWithFee = (usdcAmount * (10000 + FEE_BPS)) / 10000;
        fiatAmount = (amountWithFee * rate.rate) / (10 ** RATE_DECIMALS);

        validUntil = block.timestamp + QUOTE_VALIDITY;

        return (fiatAmount, validUntil);
    }

    /**
     * @notice Estimate total drip cost in fiat
     * @param amountPerStep Amount per step in USDC
     * @param totalSteps Total number of steps
     * @param fiatCurrency Target fiat currency
     * @return fiatAmount Total cost in fiat
     */
    function estimateDripCost(
        uint256 amountPerStep,
        uint256 totalSteps,
        string calldata fiatCurrency
    ) external view returns (uint256 fiatAmount) {
        if (amountPerStep == 0) revert InvalidAmount();
        if (totalSteps == 0) revert InvalidAmount();
        if (!supportedCurrencies[fiatCurrency]) revert UnsupportedCurrency();

        uint256 totalCrypto = amountPerStep * totalSteps;

        ExchangeRate memory rate = exchangeRates[fiatCurrency];

        if (!rate.active) revert UnsupportedCurrency();
        if (block.timestamp > rate.lastUpdated + rate.validityPeriod) {
            revert StaleRate();
        }

        // Calculate with fee
        uint256 amountWithFee = (totalCrypto * (10000 + FEE_BPS)) / 10000;
        fiatAmount = (amountWithFee * rate.rate) / (10 ** RATE_DECIMALS);

        return fiatAmount;
    }

    /**
     * @notice Get detailed quote information
     * @param usdcAmount Amount in USDC
     * @param fiatCurrency Target fiat currency
     * @return quote Detailed quote structure
     */
    function getDetailedQuote(uint256 usdcAmount, string calldata fiatCurrency)
        external
        view
        returns (Quote memory quote)
    {
        if (usdcAmount == 0) revert InvalidAmount();
        if (!supportedCurrencies[fiatCurrency]) revert UnsupportedCurrency();

        ExchangeRate memory rate = exchangeRates[fiatCurrency];

        if (!rate.active) revert UnsupportedCurrency();
        if (block.timestamp > rate.lastUpdated + rate.validityPeriod) {
            revert StaleRate();
        }

        uint256 amountWithFee = (usdcAmount * (10000 + FEE_BPS)) / 10000;
        uint256 fiatAmount = (amountWithFee * rate.rate) / (10 ** RATE_DECIMALS);

        quote = Quote({
            fiatAmount: fiatAmount,
            cryptoAmount: usdcAmount,
            rate: rate.rate,
            validUntil: block.timestamp + QUOTE_VALIDITY,
            fiatCurrency: fiatCurrency,
            cryptoToken: address(0) // Will be USDC address in production
        });

        return quote;
    }

    /**
     * @notice Update exchange rate for a currency
     * @param currency Currency code
     * @param newRate New exchange rate
     */
    function updateRate(string calldata currency, uint256 newRate)
        external
        onlyOracle
    {
        if (!supportedCurrencies[currency]) revert UnsupportedCurrency();
        if (newRate == 0) revert InvalidAmount();

        exchangeRates[currency].rate = newRate;
        exchangeRates[currency].lastUpdated = block.timestamp;

        emit RateUpdated(currency, newRate, block.timestamp);
    }

    /**
     * @notice Batch update multiple exchange rates
     * @param currencies Array of currency codes
     * @param rates Array of exchange rates
     */
    function batchUpdateRates(
        string[] calldata currencies,
        uint256[] calldata rates
    ) external onlyOracle {
        if (currencies.length != rates.length) revert InvalidAmount();

        for (uint256 i = 0; i < currencies.length; i++) {
            if (!supportedCurrencies[currencies[i]]) revert UnsupportedCurrency();
            if (rates[i] == 0) revert InvalidAmount();

            exchangeRates[currencies[i]].rate = rates[i];
            exchangeRates[currencies[i]].lastUpdated = block.timestamp;

            emit RateUpdated(currencies[i], rates[i], block.timestamp);
        }
    }

    /**
     * @notice Add support for a new currency
     * @param currency Currency code to add
     */
    function addCurrency(string calldata currency) external onlyOwner {
        _addCurrency(currency);
    }

    /**
     * @notice Remove support for a currency
     * @param currency Currency code to remove
     */
    function removeCurrency(string calldata currency) external onlyOwner {
        if (!supportedCurrencies[currency]) revert UnsupportedCurrency();

        supportedCurrencies[currency] = false;
        exchangeRates[currency].active = false;

        emit CurrencyRemoved(currency);
    }

    /**
     * @notice Get current exchange rate for a currency
     * @param currency Currency code
     * @return rate Exchange rate
     * @return lastUpdated Last update timestamp
     */
    function getRate(string calldata currency)
        external
        view
        returns (uint256 rate, uint256 lastUpdated)
    {
        if (!supportedCurrencies[currency]) revert UnsupportedCurrency();

        ExchangeRate memory exchangeRate = exchangeRates[currency];
        return (exchangeRate.rate, exchangeRate.lastUpdated);
    }

    /**
     * @notice Check if rate is stale
     * @param currency Currency code
     * @return Whether rate is stale
     */
    function isRateStale(string calldata currency) external view returns (bool) {
        if (!supportedCurrencies[currency]) return true;

        ExchangeRate memory rate = exchangeRates[currency];
        return block.timestamp > rate.lastUpdated + rate.validityPeriod;
    }

    /**
     * @notice Update oracle address
     * @param newOracle New oracle address
     */
    function setOracle(address newOracle) external onlyOwner {
        address oldOracle = oracle;
        oracle = newOracle;
        emit OracleUpdated(oldOracle, newOracle);
    }

    /**
     * @notice Internal function to add currency
     * @param currency Currency code
     */
    function _addCurrency(string memory currency) internal {
        supportedCurrencies[currency] = true;

        if (exchangeRates[currency].lastUpdated == 0) {
            exchangeRates[currency] = ExchangeRate({
                rate: 0,
                lastUpdated: 0,
                validityPeriod: 1 hours,
                active: true
            });
        } else {
            exchangeRates[currency].active = true;
        }

        emit CurrencyAdded(currency);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[50] private __gap;
}

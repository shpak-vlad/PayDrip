// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PaymentStream is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    struct Stream {
        address sender;
        address recipient;
        address token;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 withdrawn;
        bool active;
    }

    mapping(uint256 => Stream) public streams;
    mapping(address => uint256[]) public userStreams;
    mapping(address => mapping(address => uint256[])) public senderRecipientStreams;
    
    uint256 public streamCounter;
    uint256 public platformFee;
    address public feeCollector;
    
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public totalStreamsCreated;
    uint256 public totalVolumeStreamed;

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );

    event Withdrawal(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    event StreamCancelled(
        uint256 indexed streamId,
        uint256 senderBalance,
        uint256 recipientBalance
    );

    event FeeUpdated(uint256 newFee);
    event FeeCollectorUpdated(address newCollector);

    error InvalidRecipient();
    error InvalidAmount();
    error InvalidDuration();
    error StreamNotFound();
    error Unauthorized();
    error StreamNotActive();
    error InsufficientBalance();

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        streamCounter = 0;
        platformFee = 0;
        totalStreamsCreated = 0;
        totalVolumeStreamed = 0;
    }

    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Fee too high");
        platformFee = _fee;
        emit FeeUpdated(_fee);
    }

    function setFeeCollector(address _collector) external onlyOwner {
        require(_collector != address(0), "Invalid collector");
        feeCollector = _collector;
        emit FeeCollectorUpdated(_collector);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

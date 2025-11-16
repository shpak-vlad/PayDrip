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
        uint96 amount;
        uint32 startTime;
        uint32 endTime;
        uint96 withdrawn;
        bool active;
        bool cancelled;
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
    
    struct StreamMetadata {
        string description;
        bytes32 category;
    }
    
    mapping(uint256 => StreamMetadata) public streamMetadata;

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
    event BatchStreamsCreated(address indexed sender, uint256 count, uint256 totalAmount);

    error InvalidRecipient();
    error InvalidAmount();
    error InvalidDuration();
    error StreamNotFound();
    error Unauthorized();
    error StreamNotActive();
    error InsufficientBalance();
    error NotStreamParticipant();
    error StreamAlreadyCancelled();

    modifier onlyStreamSender(uint256 streamId) {
        if (streams[streamId].sender != msg.sender) revert Unauthorized();
        _;
    }

    modifier onlyStreamRecipient(uint256 streamId) {
        if (streams[streamId].recipient != msg.sender) revert Unauthorized();
        _;
    }

    modifier onlyStreamParticipant(uint256 streamId) {
        Stream memory stream = streams[streamId];
        if (stream.sender != msg.sender && stream.recipient != msg.sender) {
            revert NotStreamParticipant();
        }
        _;
    }

    modifier streamExists(uint256 streamId) {
        if (streamId >= streamCounter) revert StreamNotFound();
        _;
    }

    modifier streamIsActive(uint256 streamId) {
        if (!streams[streamId].active) revert StreamNotActive();
        _;
    }

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

    function createStream(
        address _recipient,
        address _token,
        uint256 _amount,
        uint256 _duration
    ) external nonReentrant returns (uint256) {
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_recipient == msg.sender) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();
        if (_duration == 0) revert InvalidDuration();
        if (_token == address(0)) revert InvalidAmount();

        IERC20 token = IERC20(_token);
        
        uint256 balanceBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        uint256 balanceAfter = token.balanceOf(address(this));
        
        require(balanceAfter - balanceBefore == _amount, "Token transfer mismatch");

        uint256 streamId = streamCounter++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _duration;

        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: _recipient,
            token: _token,
            amount: uint96(_amount),
            startTime: uint32(startTime),
            endTime: uint32(endTime),
            withdrawn: 0,
            active: true,
            cancelled: false
        });

        userStreams[msg.sender].push(streamId);
        userStreams[_recipient].push(streamId);
        senderRecipientStreams[msg.sender][_recipient].push(streamId);

        totalStreamsCreated++;
        totalVolumeStreamed += _amount;

        emit StreamCreated(
            streamId,
            msg.sender,
            _recipient,
            _token,
            _amount,
            startTime,
            endTime
        );

        return streamId;
    }

    function getUserStreams(address _user) external view returns (uint256[] memory) {
        return userStreams[_user];
    }

    function getSenderRecipientStreams(
        address _sender,
        address _recipient
    ) external view returns (uint256[] memory) {
        return senderRecipientStreams[_sender][_recipient];
    }

    function createMultipleStreams(
        address[] calldata _recipients,
        address _token,
        uint256[] calldata _amounts,
        uint256[] calldata _durations
    ) external nonReentrant returns (uint256[] memory) {
        require(_recipients.length == _amounts.length, "Length mismatch");
        require(_recipients.length == _durations.length, "Length mismatch");
        require(_recipients.length > 0, "Empty arrays");
        require(_recipients.length <= 50, "Too many streams");

        uint256[] memory streamIds = new uint256[](_recipients.length);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        IERC20 token = IERC20(_token);
        uint256 balanceBefore = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), totalAmount), "Transfer failed");
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore == totalAmount, "Token transfer mismatch");

        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_recipients[i] == address(0)) revert InvalidRecipient();
            if (_recipients[i] == msg.sender) revert InvalidRecipient();
            if (_amounts[i] == 0) revert InvalidAmount();
            if (_durations[i] == 0) revert InvalidDuration();

            uint256 streamId = streamCounter++;
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + _durations[i];

            require(_amounts[i] <= type(uint96).max, "Amount exceeds uint96");
            require(endTime <= type(uint32).max, "Timestamp overflow");

            streams[streamId] = Stream({
                sender: msg.sender,
                recipient: _recipients[i],
                token: _token,
                amount: uint96(_amounts[i]),
                startTime: uint32(startTime),
                endTime: uint32(endTime),
                withdrawn: 0,
                active: true,
                cancelled: false
            });

            userStreams[msg.sender].push(streamId);
            userStreams[_recipients[i]].push(streamId);
            senderRecipientStreams[msg.sender][_recipients[i]].push(streamId);

            totalStreamsCreated++;
            totalVolumeStreamed += _amounts[i];

            emit StreamCreated(
                streamId,
                msg.sender,
                _recipients[i],
                _token,
                _amounts[i],
                startTime,
                endTime
            );

            streamIds[i] = streamId;
        }

        emit BatchStreamsCreated(msg.sender, _recipients.length, totalAmount);

        return streamIds;
    }

    function withdraw(uint256 streamId) 
        external 
        nonReentrant 
        streamExists(streamId)
        streamIsActive(streamId)
        onlyStreamRecipient(streamId)
        returns (uint256) 
    {
        Stream storage stream = streams[streamId];
        
        uint256 withdrawable = _calculateWithdrawable(streamId);
        if (withdrawable == 0) revert InsufficientBalance();

        uint256 newWithdrawn = uint256(stream.withdrawn) + withdrawable;
        require(newWithdrawn <= type(uint96).max, "Withdrawal overflow");
        stream.withdrawn = uint96(newWithdrawn);

        uint256 fee = 0;
        if (platformFee > 0 && feeCollector != address(0)) {
            fee = (withdrawable * platformFee) / FEE_DENOMINATOR;
            uint256 amountAfterFee = withdrawable - fee;
            
            IERC20(stream.token).transfer(feeCollector, fee);
            IERC20(stream.token).transfer(stream.recipient, amountAfterFee);
        } else {
            IERC20(stream.token).transfer(stream.recipient, withdrawable);
        }

        emit Withdrawal(streamId, stream.recipient, withdrawable);
        
        return withdrawable;
    }

    function _calculateWithdrawable(uint256 streamId) internal view returns (uint256) {
        Stream memory stream = streams[streamId];
        
        if (!stream.active) return 0;
        
        uint256 currentTime = block.timestamp;
        if (currentTime <= stream.startTime) return 0;
        
        uint256 elapsed;
        if (currentTime >= stream.endTime) {
            elapsed = stream.endTime - stream.startTime;
        } else {
            elapsed = currentTime - stream.startTime;
        }
        
        uint256 duration = stream.endTime - stream.startTime;
        if (duration == 0) return 0;
        
        uint256 totalStreamed = (uint256(stream.amount) * elapsed) / duration;
        uint256 withdrawn = uint256(stream.withdrawn);
        
        return totalStreamed > withdrawn ? totalStreamed - withdrawn : 0;
    }

    function getStreamInfo(uint256 streamId) 
        external 
        view 
        streamExists(streamId)
        returns (
            address sender,
            address recipient,
            address token,
            uint256 amount,
            uint256 startTime,
            uint256 endTime,
            uint256 withdrawn,
            bool active,
            bool cancelled
        )
    {
        Stream memory stream = streams[streamId];
        return (
            stream.sender,
            stream.recipient,
            stream.token,
            uint256(stream.amount),
            uint256(stream.startTime),
            uint256(stream.endTime),
            uint256(stream.withdrawn),
            stream.active,
            stream.cancelled
        );
    }

    function setStreamMetadata(
        uint256 streamId,
        string calldata description,
        bytes32 category
    ) external streamExists(streamId) onlyStreamSender(streamId) {
        streamMetadata[streamId] = StreamMetadata({
            description: description,
            category: category
        });
    }

    function getStreamMetadata(uint256 streamId)
        external
        view
        streamExists(streamId)
        returns (string memory description, bytes32 category)
    {
        StreamMetadata memory metadata = streamMetadata[streamId];
        return (metadata.description, metadata.category);
    }

    function calculateWithdrawable(uint256 streamId) 
        external 
        view 
        streamExists(streamId)
        returns (uint256) 
    {
        return _calculateWithdrawable(streamId);
    }

    function cancelStream(uint256 streamId)
        external
        nonReentrant
        streamExists(streamId)
        streamIsActive(streamId)
        onlyStreamSender(streamId)
    {
        Stream storage stream = streams[streamId];
        
        uint256 withdrawable = _calculateWithdrawable(streamId);
        uint256 totalAmount = uint256(stream.amount);
        uint256 withdrawn = uint256(stream.withdrawn);
        uint256 refundable = totalAmount - withdrawn - withdrawable;

        stream.active = false;
        stream.cancelled = true;

        IERC20 token = IERC20(stream.token);
        address _recipient = stream.recipient;
        address _sender = stream.sender;
        
        if (withdrawable > 0) {
            token.transfer(_recipient, withdrawable);
        }
        
        if (refundable > 0) {
            token.transfer(_sender, refundable);
        }

        emit StreamCancelled(streamId, refundable, withdrawable);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
// Gas optimizations applied
// Fix for zero amount edge case

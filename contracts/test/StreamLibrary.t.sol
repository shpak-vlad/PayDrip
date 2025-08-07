// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/libraries/StreamLibrary.sol";

contract StreamLibraryTest is Test {
    using StreamLibrary for StreamLibrary.StreamData;

    function testCalculateStreamedAmount() public {
        StreamLibrary.StreamData memory stream = StreamLibrary.StreamData({
            sender: address(1),
            recipient: address(2),
            token: address(3),
            amount: 1000 ether,
            startTime: 1000,
            endTime: 2000,
            withdrawn: 0,
            active: true,
            cancelled: false
        });

        uint256 streamed = StreamLibrary.calculateStreamedAmount(stream, 1500);
        assertEq(streamed, 500 ether);
    }

    function testCalculateWithdrawableAmount() public {
        StreamLibrary.StreamData memory stream = StreamLibrary.StreamData({
            sender: address(1),
            recipient: address(2),
            token: address(3),
            amount: 1000 ether,
            startTime: 1000,
            endTime: 2000,
            withdrawn: 300 ether,
            active: true,
            cancelled: false
        });

        uint256 withdrawable = StreamLibrary.calculateWithdrawableAmount(stream, 1500);
        assertEq(withdrawable, 200 ether);
    }

    function testGetStreamStatus() public {
        StreamLibrary.StreamData memory stream = StreamLibrary.StreamData({
            sender: address(1),
            recipient: address(2),
            token: address(3),
            amount: 1000 ether,
            startTime: 1000,
            endTime: 2000,
            withdrawn: 0,
            active: true,
            cancelled: false
        });

        assertEq(uint(StreamLibrary.getStreamStatus(stream, 500)), uint(StreamLibrary.StreamStatus.Pending));
        assertEq(uint(StreamLibrary.getStreamStatus(stream, 1500)), uint(StreamLibrary.StreamStatus.Active));
        assertEq(uint(StreamLibrary.getStreamStatus(stream, 2500)), uint(StreamLibrary.StreamStatus.Completed));
    }

    function testValidateStream() public {
        StreamLibrary.StreamData memory validStream = StreamLibrary.StreamData({
            sender: address(1),
            recipient: address(2),
            token: address(3),
            amount: 1000 ether,
            startTime: 1000,
            endTime: 2000,
            withdrawn: 0,
            active: true,
            cancelled: false
        });

        assertTrue(StreamLibrary.validateStream(validStream));

        validStream.recipient = address(0);
        assertFalse(StreamLibrary.validateStream(validStream));
    }
}

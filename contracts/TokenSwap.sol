// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;

contract TokenSwap {
    event TokenSwap(
    );

    function swapPRewTokenToDai(uint _prewAmount) external {
        emit TokenSwap();
    }

    function estimateSwap(uint _prewAmount) external returns (uint) {
        // dummy assumption, 1 reward token = 1 dai
        return _prewAmount;
    }
}
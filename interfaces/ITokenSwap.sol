// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;

interface ITokenSwap {
    function swapPRewTokenToDai(uint _prewAmount) external;

    function estimateSwap(uint _prewAmount) external view returns (uint256);
}
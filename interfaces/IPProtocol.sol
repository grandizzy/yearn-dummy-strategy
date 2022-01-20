// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;

interface IPProtocol {
    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function getReward() external;

    function getBalance(address _staker) external view returns (uint256);

    function earned(address account) external view returns (uint256);
}
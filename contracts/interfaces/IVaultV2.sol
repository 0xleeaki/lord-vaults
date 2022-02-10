// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./IVaultMaster.sol";

interface IVaultV2 {
    function initialize(
        uint256 _vaultTemplateId,
        address _owner,
        address _vaultMaster
    ) external;

    function vaultMaster() external view returns (IVaultMaster);

    function liquidityRouter() external view returns (address);

    function isSingleStaking() external view returns (bool);

    function vaultTemplateId() external view returns (uint256);

    function rewardToken() external view returns (address);

    function wantToken() external view returns (address);

    function pending() external view returns (uint256);

    function balanceInFarm() external view returns (uint256);

    function canAbandon() external view returns (bool);

    function deposit(uint256 _wantAmt) external;

    function claim() external returns (uint256 _amount);

    function exit() external returns (uint256 _withdrawnAmount, uint256 _rewardAmount);

    function withdraw(uint256 _wantAmt) external returns (uint256 _withdrawnAmount, uint256 _rewardAmount);
}

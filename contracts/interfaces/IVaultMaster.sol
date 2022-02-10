// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IVaultMaster {
    function owner() external view returns (address);

    function initialize(address _owner, address _routeRepository) external;

    function addVault(address _vaultAddress) external;

    function removeVault(address _vaultAddress) external;
}

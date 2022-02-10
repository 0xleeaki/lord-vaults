// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IVaultPolicyV2 {
    function canDeposit(address _strategy, address _owner) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IVaultFactoryV2 {
    function policy() external view returns (address);
    function routerRepository() external view returns (address);
}

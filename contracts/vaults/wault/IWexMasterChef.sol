// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IWexMasterChef {
    function poolInfo(uint256 poolId)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accRewardPerShare
        );

    function userInfo(uint256 poolId, address user) external view returns (uint256 amount, uint256 debt);

    function wex() external view returns (address);

    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards
    ) external;

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _withdrawRewards
    ) external;

    function claim(uint256 _pid) external;

    function pendingWex(uint256 _pid, address _user) external view returns (uint256);
}

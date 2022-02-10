// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../_base/VaultBaseV2.sol";
import "./IWexMasterChef.sol";

contract VaultWex is VaultBaseV2 {
    using SafeERC20 for IERC20;

    IWexMasterChef public masterChef;
    uint256 public poolId;
    uint256 public swapTimeout;

    constructor(
        address _liquidityRouter,
        IWexMasterChef _masterChef,
        uint256 _poolId
    ) VaultBaseV2() {
        liquidityRouter = _liquidityRouter;
        poolId = _poolId;
        masterChef = _masterChef;
        (wantToken, , , ) = masterChef.poolInfo(_poolId);
        rewardToken = _masterChef.wex();
    }

    // ========== views =================

    function balanceInFarm() public view override returns (uint256) {
        (uint256 _amount, ) = masterChef.userInfo(poolId, address(this));
        return _amount;
    }

    function pending() public view override returns (uint256) {
        uint256 _pendingInFarm = masterChef.pendingWex(poolId, address(this));
        uint256 _pendingInVault = IERC20(rewardToken).balanceOf(address(this));
        return _pendingInFarm + _pendingInVault;
    }

    function canAbandon() public view override returns (bool) {
        bool _noRewardTokenLeft = IERC20(rewardToken).balanceOf(address(this)) == 0;
        bool _noLpTokenLeft = IERC20(wantToken).balanceOf(address(this)) == 0;
        bool _noPending = pending() == 0;
        return _noRewardTokenLeft && _noLpTokenLeft && _noPending;
    }

    // ========== vault core functions ===========

    function deposit(uint256 _wantAmt) public override onlyDepositor nonReentrant {
        IERC20(wantToken).safeTransferFrom(msg.sender, address(this), _wantAmt);
        _depositToFarm();
    }

    function exit() external override onlyDepositor returns (uint256 _withdrawnAmount, uint256 _rewardAmount) {
        uint256 _balance = balanceInFarm();
        _widthdrawFromFarm(_balance, true);
        (_withdrawnAmount, _rewardAmount) = _withdrawFromVault();
    }

    function withdraw(uint256 _wantAmt)
        public
        override
        onlyDepositor
        nonReentrant
        returns (uint256 _withdrawnAmount, uint256 _rewardAmount)
    {
        require(_wantAmt > 0, "_wantAmt <= 0");
        _widthdrawFromFarm(_wantAmt, false);
        (_withdrawnAmount, _rewardAmount) = _withdrawFromVault();
    }

    function claim() external override onlyDepositor returns (uint256 _amount) {
        masterChef.claim(poolId);
        _amount = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > 0) {
            IERC20(rewardToken).safeTransfer(msg.sender, _amount);
        }
    }

    // ============= internal functions ================

    function _withdrawFromVault() internal returns (uint256 _withdrawnAmount, uint256 _rewardAmount) {
        _rewardAmount = IERC20(rewardToken).balanceOf(address(this));
        if (_rewardAmount > 0) {
            IERC20(rewardToken).safeTransfer(msg.sender, _rewardAmount);
        }
        _withdrawnAmount = IERC20(wantToken).balanceOf(address(this));
        if (_withdrawnAmount > 0) {
            IERC20(wantToken).safeTransfer(msg.sender, _withdrawnAmount);
        }
    }

    function _depositToFarm() internal {
        IERC20 wantToken = IERC20(wantToken);
        uint256 wantAmt = wantToken.balanceOf(address(this));
        wantToken.safeIncreaseAllowance(address(masterChef), wantAmt);
        masterChef.deposit(poolId, wantAmt, false);
    }

    function _widthdrawFromFarm(uint256 _wantAmt, bool _claimRewards) internal {
        masterChef.withdraw(poolId, _wantAmt, _claimRewards);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../_base/VaultBaseV2.sol";
import "./IQuickswapStakingRewards.sol";

contract VaultQuickswapLP is VaultBaseV2 {
    using SafeERC20 for IERC20;

    IQuickswapStakingRewards public stakingRewards;

    // hardcoded when deploy
    constructor(address _liquidityRouter, IQuickswapStakingRewards _stakingRewards) VaultBaseV2() {
        liquidityRouter = _liquidityRouter;
        stakingRewards = _stakingRewards;
        wantToken = stakingRewards.stakingToken();
        rewardToken = stakingRewards.rewardsToken();
    }

    // ========== views =================

    function balanceInFarm() public view override returns (uint256) {
        return stakingRewards.balanceOf(address(this));
    }

    function pending() public view override returns (uint256) {
        uint256 _pendingInFarm = stakingRewards.earned(address(this));
        uint256 _pendingInVault = IERC20(rewardToken).balanceOf(address(this));
        return _pendingInFarm + _pendingInVault;
    }

    function canAbandon() public view override returns (bool) {
        bool _noRewardTokenLeft = IERC20(rewardToken).balanceOf(address(this)) == 0;
        bool _noLpTokenLeft = IERC20(wantToken).balanceOf(address(this)) == 0;
        bool _noPending = pending() == 0;
        return _noRewardTokenLeft && _noLpTokenLeft && _noPending;
    }

    // ========== main functions ==========

    function deposit(uint256 _wantAmt) external override onlyDepositor nonReentrant {
        IERC20(wantToken).safeTransferFrom(address(msg.sender), address(this), _wantAmt);
        _depositToFarm();
    }

    function claim() external override onlyDepositor returns (uint256 _amount) {
        stakingRewards.getReward();
        _amount = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > 0) {
            IERC20(rewardToken).safeTransfer(msg.sender, _amount);
        }
    }

    function exit() external override onlyDepositor returns (uint256 _withdrawnAmount, uint256 _rewardAmount) {
        stakingRewards.exit();
        (_withdrawnAmount, _rewardAmount) = _withdrawFromVault();
    }

    function withdraw(uint256 _wantAmt)
        external
        override
        onlyDepositor
        nonReentrant
        returns (uint256 _withdrawnAmount, uint256 _rewardAmount)
    {
        require(_wantAmt > 0, "_wantAmt <= 0");
        _widthdrawFromFarm(_wantAmt);
        (_withdrawnAmount, _rewardAmount) = _withdrawFromVault();
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
        IERC20 _token = IERC20(wantToken);
        uint256 wantAmt = _token.balanceOf(address(this));
        _token.safeIncreaseAllowance(address(stakingRewards), wantAmt);
        stakingRewards.stake(wantAmt);
    }

    function _widthdrawFromFarm(uint256 _wantAmt) internal {
        stakingRewards.withdraw(_wantAmt);
    }
}

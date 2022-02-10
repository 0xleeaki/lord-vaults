// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IVaultV2.sol";
import "../../interfaces/IVaultMaster.sol";

abstract contract VaultBaseV2 is IVaultV2, Ownable, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;

    IVaultMaster public override vaultMaster;
    uint256 public override vaultTemplateId;
    address public override liquidityRouter;
    address public override rewardToken;
    address public override wantToken;
    bool public override isSingleStaking;

    // modifiers

    modifier onlyDepositor() {
        require(msg.sender == owner() || msg.sender == address(vaultMaster), "Only owner or vault master can deposit");
        _;
    }

    // constructors

    function initialize(
        uint256 _vaultTemplateId,
        address _owner,
        address _vaultMaster
    ) external override initializer onlyOwner {
        require(_owner != address(0), "invalid address");
        transferOwnership(_owner);
        vaultMaster = IVaultMaster(_vaultMaster);
        require(vaultMaster.owner() == _owner, "invalid vault master");
        vaultTemplateId = _vaultTemplateId;
    }

    // virtual functions

    function pending() external view virtual override returns (uint256);

    function balanceInFarm() external view virtual override returns (uint256);

    function canAbandon() external view virtual override returns (bool);

    function deposit(uint256 _wantAmt) external virtual override;

    function claim() external virtual override returns (uint256 _amount);

    function exit() external virtual override returns (uint256 _withdrawnAmount, uint256 _rewardAmount);

    function withdraw(uint256 _wantAmt) external virtual override returns (uint256 _withdrawnAmount, uint256 _rewardAmount);

    // =========== emergency functions =================

    function rescueFund(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) external onlyOwner returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, string("DevFund::executeTransaction: Transaction execution reverted."));
        return returnData;
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVaultV2.sol";
import "./interfaces/IVaultFactoryV2.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IRouteRepository.sol";

contract VaultMaster is Ownable, Initializable {
    using SafeERC20 for IERC20;

    struct VaultInfo {
        uint256 templateId;
        uint256 balanceInFarm;
        uint256 pendingRewards;
        address wantToken;
        address rewardToken;
        bool canAbandon;
    }

    IVaultFactoryV2 public factory;
    address[] public vaults;
    mapping(address => bool) public vaultsMapping;
    mapping(address => address) public claimStrategies;

    // ratios
    uint256 private constant RATIO_PRECISION = 1e6;
    uint256 private constant SWAP_TIME_OUT = 900; // 15 minutes
    uint256 public constant slippage = 20000; // 2%
    IRouteRepository public routeRepository;

    // events
    event Deposited(address indexed _vault, address _token, uint256 _amount);
    event Withdrawn(address indexed _vault, address _token, uint256 _amount);
    event Claimed(address indexed _vault, address _token, uint256 _amount);

    // modifiers
    modifier onlyFactoryOrOwner() {
        require(msg.sender == address(factory) || msg.sender == owner(), "Only factory or owner can call");
        _;
    }

    // constructors
    constructor() {
        factory = IVaultFactoryV2(msg.sender);
    }

    function initialize(address _owner, address _routeRepository) external initializer {
        require(msg.sender == address(factory), "Only factory can call initialize()");
        require(_routeRepository != address(0), "Invalid route repository");
        transferOwnership(_owner);
        routeRepository = IRouteRepository(_routeRepository);
    }

    // =========== views =================================

    function vaultInfo(address _vaultAddress) external view returns (VaultInfo memory) {
        require(vaultsMapping[_vaultAddress], "vault not exist");
        IVaultV2 vault = IVaultV2(_vaultAddress);
        VaultInfo memory info = VaultInfo(
            vault.vaultTemplateId(),
            vault.balanceInFarm(),
            vault.pending(),
            vault.wantToken(),
            vault.rewardToken(),
            vault.canAbandon()
        );
        return info;
    }

    // =========== deposit function ======================

    function deposit(address _vaultAddress, uint256 _wantAmt) external onlyOwner {
        _deposit(msg.sender, _vaultAddress, _wantAmt, false);
    }

    function _deposit(
        address _depositor,
        address _vaultAddress,
        uint256 _wantAmt,
        bool _autoCompound
    ) internal {
        require(vaultsMapping[_vaultAddress], "vault not exist");

        IVaultV2 vault = IVaultV2(_vaultAddress);
        IERC20 _wantToken = IERC20(vault.wantToken());
        _wantToken.safeApprove(_vaultAddress, 0);
        _wantToken.safeApprove(_vaultAddress, _wantAmt);

        // 1. transfer from owner to vaultMaster
        if (!_autoCompound) {
            _wantToken.safeTransferFrom(_depositor, address(this), _wantAmt);
        }

        // 2. call vault.deposit()
        vault.deposit(_wantAmt);

        emit Deposited(_vaultAddress, address(_wantToken), _wantAmt);
    }

    // =========== withdraw function ======================

    function withdraw(address _vaultAddress, uint256 _amount) external onlyOwner {
        require(vaultsMapping[_vaultAddress], "vault not exist");
        IVaultV2 vault = IVaultV2(_vaultAddress);

        // 1. withdraw
        (uint256 _withdrawnAmount, uint256 _rewardAmount) = vault.withdraw(_amount);

        // 2. transfer LP back to owner
        IERC20 _wantToken = IERC20(vault.wantToken());
        _wantToken.safeTransfer(msg.sender, _withdrawnAmount);

        // 3. reward token => claim strategy
        _applyClaimStrategy(_vaultAddress, _rewardAmount);

        emit Withdrawn(_vaultAddress, address(_wantToken), _withdrawnAmount);
    }

    // =========== exit function ======================

    function exit(address _vaultAddress) external onlyOwner {
        require(vaultsMapping[_vaultAddress], "vault not exist");
        IVaultV2 vault = IVaultV2(_vaultAddress);

        // 1. withdraw
        (uint256 _withdrawnAmount, uint256 _rewardAmount) = vault.exit();

        // 2. transfer LP back to owner
        IERC20 _wantToken = IERC20(vault.wantToken());
        _wantToken.safeTransfer(msg.sender, _withdrawnAmount);

        // 3. reward token => claim strategy
        _applyClaimStrategy(_vaultAddress, _rewardAmount);

        emit Withdrawn(_vaultAddress, address(_wantToken), _withdrawnAmount);
    }

    // =========== compound functions =====================

    // compound all vaults
    function compoundAll() external onlyOwner {
        _compoundMultiple(vaults);
    }

    function compound(address[] calldata _vaultAddresses) public onlyOwner {
        _compoundMultiple(_vaultAddresses);
    }

    // compound multiple vaults
    function _compoundMultiple(address[] memory _vaultAddresses) internal {
        for (uint256 i = 0; i < _vaultAddresses.length; i++) {
            _compound(_vaultAddresses[i]);
        }
    }

    // compound 1 specific vault
    function _compound(address _vaultAddress) internal {
        if (!vaultsMapping[_vaultAddress]) {
            return;
        }
        IVaultV2 vault = IVaultV2(_vaultAddress);

        // 1. claim rewards
        uint256 _amount = vault.claim();

        // 2. compounding
        if (_amount == 0) {
            return;
        }

        IUniswapV2Pair wantLP = IUniswapV2Pair(vault.wantToken());
        IERC20 token0 = IERC20(wantLP.token0());
        IERC20 token1 = IERC20(wantLP.token1());
        address rewardToken = vault.rewardToken();
        uint256 _token0Amount = 0;
        uint256 _token1Amount = 0;
        if (rewardToken != address(token0)) {
            _token0Amount = _swap(rewardToken, address(token0), _amount / 2);
        } else {
            _token0Amount = _amount / 2;
        }

        if (rewardToken != address(token1)) {
            _token1Amount = _swap(rewardToken, address(token1), _amount / 2);
        } else {
            _token1Amount = _amount / 2;
        }

        uint256 _addedLpAmount = 0;
        if (_token0Amount > 0 && _token1Amount > 0) {
            address _liquidityRouter = vault.liquidityRouter();
            token0.safeIncreaseAllowance(_liquidityRouter, _token0Amount);
            token1.safeIncreaseAllowance(_liquidityRouter, _token1Amount);
            (, , _addedLpAmount) = IUniswapV2Router(_liquidityRouter).addLiquidity(
                address(token0),
                address(token1),
                _token0Amount,
                _token1Amount,
                0,
                0,
                address(this),
                block.timestamp + SWAP_TIME_OUT
            );
        }

        if (_addedLpAmount > 0) {
            _deposit(address(this), _vaultAddress, _addedLpAmount, true);
        }
    }

    // =========== claim functions =====================

    function claimAll() external onlyOwner {
        // claim all vaults
        _claimMultiple(vaults);
    }

    function claim(address[] calldata _vaultAddresses) public onlyOwner {
        _claimMultiple(_vaultAddresses);
    }

    function _claimMultiple(address[] memory _vaultAddresses) internal {
        // claim multiple vaults
        for (uint256 i = 0; i < _vaultAddresses.length; i++) {
            _claim(_vaultAddresses[i]);
        }
    }

    function _claim(address _vaultAddress) internal {
        // claim 1 specific vault
        if (vaultsMapping[_vaultAddress]) {
            IVaultV2 vault = IVaultV2(_vaultAddress);
            // 1. claim rewards
            uint256 _amount = vault.claim();
            // 2. apply claim strategy
            _applyClaimStrategy(_vaultAddress, _amount);
        }
    }

    function _applyClaimStrategy(address _vaultAddress, uint256 _amount) internal {
        require(vaultsMapping[_vaultAddress], "Vault not existed");
        IVaultV2 vault = IVaultV2(_vaultAddress);
        IERC20 rewardToken = IERC20(vault.rewardToken());
        address targetClaimToken = claimStrategies[_vaultAddress];
        if (targetClaimToken == address(0)) {
            rewardToken.safeTransfer(owner(), _amount);
            emit Claimed(_vaultAddress, address(rewardToken), _amount);
        } else {
            uint256 _outputAmt = _swap(address(rewardToken), targetClaimToken, _amount);
            if (_outputAmt > 0) {
                IERC20(targetClaimToken).safeTransfer(owner(), _outputAmt);
            }
            emit Claimed(_vaultAddress, targetClaimToken, _outputAmt);
        }
    }

    // =========== factory functions ===================

    function addVault(address _vaultAddress) external onlyFactoryOrOwner() {
        require(!vaultsMapping[_vaultAddress], "Vault existed");
        vaults.push(_vaultAddress);
        vaultsMapping[_vaultAddress] = true;
    }

    function removeVault(address _vaultAddress) external onlyOwner() {
        require(vaultsMapping[_vaultAddress], "Vault not existed");
        IVaultV2 vault = IVaultV2(_vaultAddress);
        require(vault.canAbandon(), "Vault cannot be abandonned");
        delete vaultsMapping[_vaultAddress];
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == _vaultAddress) {
                vaults[i] = vaults[vaults.length - 1];
                break;
            }
        }
        vaults.pop();
    }

    // =========== dust functions ======================

    function dustBalance(address _dustToken) external view returns (uint256) {
        return IERC20(_dustToken).balanceOf(address(this));
    }

    function collectDustTokens(address[] calldata _dustTokens) external onlyOwner {
        for (uint256 i = 0; i < _dustTokens.length; i++) {
            uint256 _dustBalance = IERC20(_dustTokens[i]).balanceOf(address(this));
            IERC20(_dustTokens[i]).safeTransfer(msg.sender, _dustBalance);
        }
    }

    function cleanDustTokens(address[] calldata _dustTokens, address _targetToken) external onlyOwner {
        uint256 _outputAmt = 0;
        for (uint256 i = 0; i < _dustTokens.length; i++) {
            uint256 _dustBalance = IERC20(_dustTokens[i]).balanceOf(address(this));
            IERC20(_dustTokens[i]).safeTransfer(msg.sender, _dustBalance);
            _outputAmt = _outputAmt + _swap(_dustTokens[i], _targetToken, _dustBalance);
        }
        IERC20(_targetToken).safeTransfer(msg.sender, _outputAmt);
    }

    // =========== swap functions ======================

    function _swap(
        address _inputToken,
        address _outputToken,
        uint256 _inputAmount
    ) internal returns (uint256) {
        if (_inputAmount == 0) {
            return 0;
        }
        (address _router, address[] memory _path) = routeRepository.getSwapRoute(_inputToken, _outputToken);
        require(_router != address(0), "invalid route");
        require(_path[0] == _inputToken, "Route must start with src token");
        require(_path[_path.length - 1] == _outputToken, "Route must end with dst token");
        IERC20(_inputToken).safeApprove(_router, 0);
        IERC20(_inputToken).safeApprove(_router, _inputAmount);
        uint256 _balanceBefore = IERC20(_outputToken).balanceOf(address(this));
        _safeSwap(_router, _inputAmount, slippage, _path, address(this), block.timestamp + SWAP_TIME_OUT);
        uint256 _balanceAfter = IERC20(_outputToken).balanceOf(address(this));
        return _balanceAfter - _balanceBefore;
    }

    function _safeSwap(
        address _swapRouterAddress,
        uint256 _amountIn,
        uint256 _slippage,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal {
        IUniswapV2Router _swapRouter = IUniswapV2Router(_swapRouterAddress);
        require(_path.length > 0, "invalidSwapPath");
        uint256[] memory amounts = _swapRouter.getAmountsOut(_amountIn, _path);
        uint256 _minAmountOut = (amounts[amounts.length - 1] * (RATIO_PRECISION - _slippage)) / RATIO_PRECISION;
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amountIn, _minAmountOut, _path, _to, _deadline);
    }

    // =========== configuration =======================

    function setClaimStategy(address _vaultAddress, address _target) external onlyOwner {
        require(vaultsMapping[_vaultAddress], "vault not exist");
        claimStrategies[_vaultAddress] = _target;
    }

    function removeClaimStategy(address _vaultAddress) external onlyOwner {
        delete claimStrategies[_vaultAddress];
    }

    function useCustomRouteRepository(IRouteRepository _routeRepository) external onlyOwner {
        require(address(_routeRepository) != address(0), "invalid address");
        routeRepository = _routeRepository;
    }

    // =========== emergency functions =================

    function rescueFund(address _token, uint256 _amount) public virtual onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) public onlyOwner returns (bytes memory) {
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

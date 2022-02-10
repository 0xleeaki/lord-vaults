// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IVaultMaster.sol";
import "./interfaces/IVaultV2.sol";

contract VaultFactoryV2 is Ownable, Initializable {
    struct VaultTemplate {
        bytes code;
        bytes arguments;
        bool deprecated;
    }

    struct VaultMasterTemplate {
        bytes code;
        bytes arguments;
    }

    VaultTemplate[] public vaultTemplates;
    VaultMasterTemplate private vaultMasterTemplate;
    mapping(address => address) public userVaultMasters;

    address public routerRepository;

    // EVENTS
    event RouterRepositorySet(address _routerRepository);
    event VaultCreated(address indexed _owner, address _vault);
    event VaultMasterCreated(address indexed _owner, address _vaultMaster);
    event VaultMasterRemoved(address indexed _owner, address _vaultMaster);

    // ========= INITIALIZER =========
    function initialize(address _routerRepository) external onlyOwner initializer {
        routerRepository = _routerRepository;
    }

    // ========= PUBLIC FUNCTIONS =========
    function getUserVaultMaster(address _user) external view returns (address) {
        return userVaultMasters[_user];
    }

    function createVault(uint256 _templateId) external returns (address _vault) {
        address _vaultMaster = userVaultMasters[msg.sender];
        require(_vaultMaster != address(0), "Vault master not existed");

        VaultTemplate storage _template = vaultTemplates[_templateId];
        bytes memory bytecode = _template.code;
        require(bytecode.length != 0, "vault is not supported");
        bytes memory arguments = _template.arguments;
        require(arguments.length != 0, "invalid vault arguments");

        bytecode = abi.encodePacked(bytecode, arguments);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, arguments, block.number));

        // solhint-disable no-inline-assembly
        assembly {
            _vault := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(_vault)) {
                revert(0, 0)
            }
        }

        IVaultV2(_vault).initialize(_templateId, msg.sender, _vaultMaster);
        IVaultMaster(_vaultMaster).addVault(_vault);
        emit VaultCreated(msg.sender, _vault);
    }

    function createVaultMaster() external returns (address _vaultMaster) {
        require(userVaultMasters[msg.sender] == address(0), "Vault master existed");

        bytes memory bytecode = vaultMasterTemplate.code;
        require(bytecode.length != 0, "vault master is not supported");
        bytes memory arguments = vaultMasterTemplate.arguments;

        bytecode = abi.encodePacked(bytecode, arguments);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, arguments, block.number));

        // solhint-disable no-inline-assembly
        assembly {
            _vaultMaster := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(_vaultMaster)) {
                revert(0, 0)
            }
        }

        IVaultMaster(_vaultMaster).initialize(msg.sender, routerRepository);
        userVaultMasters[msg.sender] = _vaultMaster;
        emit VaultMasterCreated(msg.sender, _vaultMaster);
    }

    function removeVaultMaster() external {
        address vaultAddress = userVaultMasters[msg.sender];
        require(vaultAddress != address(0), "Vault master not existed");
        delete userVaultMasters[msg.sender];
        emit VaultMasterRemoved(msg.sender, vaultAddress);
    }

    // ========= RESTRICTED FUNCTIONS =========
    function setRouter(address _routerRepository) external onlyOwner {
        require(routerRepository != address(0x0), "emptyAddress");
        require(routerRepository != _routerRepository, "unchanged");
        routerRepository = _routerRepository;
        emit RouterRepositorySet(_routerRepository);
    }

    function updateVaultMasterTemplate(bytes calldata _code, bytes calldata _initArguments) external onlyOwner {
        vaultMasterTemplate = VaultMasterTemplate(_code, _initArguments);
    }

    function addTemplate(bytes calldata _code, bytes calldata _initArguments) external onlyOwner {
        VaultTemplate memory _template = VaultTemplate(_code, _initArguments, false);
        vaultTemplates.push(_template);
    }

    function removeTemplate(uint256 tid) external onlyOwner {
        vaultTemplates[tid] = VaultTemplate("", "", true);
    }
}

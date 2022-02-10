import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';
import {routers} from './known_contracts';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute, get} = deployments;
  const {creator} = await getNamedAccounts();

  const router = await get('RouteRepository');

  await deploy('VaultFactoryV2', {
    from: creator,
    args: [],
    log: true,
  });

  await execute('VaultFactoryV2', {from: creator, log: true}, 'initialize', router.address);

  const artifact_VaultMaster = await deployments.getArtifact('VaultMaster');
  const arg_VaultMaster = await defaultAbiCoder.encode([], []);
  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'updateVaultMasterTemplate',
    artifact_VaultMaster.bytecode,
    arg_VaultMaster
  );

  const qsStakingReward_ETH_USDC = {address: '0x4A73218eF2e820987c59F838906A82455F42D98b'};
  const artifact_VaultQuickswapLP = await deployments.getArtifact('VaultQuickswapLP');
  const args_ETH_USDC = await defaultAbiCoder.encode(
    ['address', 'address'],
    [routers.quickswap, qsStakingReward_ETH_USDC.address]
  );

  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultQuickswapLP.bytecode,
    args_ETH_USDC
  );
};

run.tags = ['matic', 'quickswap_1'];

run.skip = async (hre) => {
  return hre.network.name !== 'matic';
};
export default run;

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
};

run.tags = ['bsc', 'factory'];

run.skip = async (hre) => {
  return hre.network.name !== 'bsc';
};
export default run;

import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';
import {routers} from './known_contracts';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {execute} = deployments;
  const {creatorpoly} = await getNamedAccounts();

  const wexMaster = {address: '0xc8bd86e5a132ac0bf10134e270de06a8ba317bfe'};
  const artifact_VaultWex = await deployments.getArtifact('VaultWex');

  // 1. wault: matic/usdc
  const argsPool_eth_usdt = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [routers.wault, wexMaster.address, 5]
  );
  await execute(
    'VaultFactoryV2',
    {from: creatorpoly, log: true},
    'addTemplate',
    artifact_VaultWex.bytecode,
    argsPool_eth_usdt
  );
};

run.tags = ['matic', 'wex_1'];

run.skip = async (hre) => {
  return hre.network.name !== 'matic';
};
export default run;

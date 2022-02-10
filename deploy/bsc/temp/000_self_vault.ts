import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute, get} = deployments;
  const {creator} = await getNamedAccounts();
  const routers = {
    pancakeSwapV2: '',
    wault: '0xd48745e39bbed146eec15b79cbf964884f9877c2',
  };

  const wexMaster = {address: '0x22fB2663C7ca71Adc2cc99481C77Aaf21E152e2D'};
  const routeRepository = await get('RouteRepository');

  // 0. wault: eth/usdt
  await deploy('VaultWex', {
    contract: 'VaultWex',
    from: creator,
    log: true,
    args: [routers.wault, wexMaster.address, 44],
  });

  await execute(
    'VaultWex',
    {from: creator, log: true},
    'initialize',
    0,
    creator,
    '0x0d6ba0aB090A68F32664E8ae1729c724A6BF94Ad'
  );
};

run.tags = ['bsc', 'self'];

run.skip = async (hre) => {
  return hre.network.name !== 'bsc';
};
export default run;

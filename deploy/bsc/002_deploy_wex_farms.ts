import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';
import {routers} from './known_contracts';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {execute} = deployments;
  const {creator} = await getNamedAccounts();

  const wexMaster = {address: '0x22fB2663C7ca71Adc2cc99481C77Aaf21E152e2D'};
  const artifact_VaultWex = await deployments.getArtifact('VaultWex');

  // 0. wault: eth/usdt
  const argsPool_eth_usdt = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [routers.wault, wexMaster.address, 44]
  );
  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultWex.bytecode,
    argsPool_eth_usdt
  );

  // 1. wault: wbnb/busd
  const argsPool_wbnb_busd = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [routers.wault, wexMaster.address, 6]
  );
  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultWex.bytecode,
    argsPool_wbnb_busd
  );

  // 2. wault: btcb/busd
  const argsPool_btcb_busd = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [routers.wault, wexMaster.address, 8]
  );
  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultWex.bytecode,
    argsPool_btcb_busd
  );

  // 3. wault: btcb/eth
  const argsPool_btcb_eth = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [routers.wault, wexMaster.address, 33]
  );
  await execute(
    'VaultFactoryV2',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultWex.bytecode,
    argsPool_btcb_eth
  );
};

run.tags = ['bsc', 'wex_1'];

run.skip = async (hre) => {
  return hre.network.name !== 'bsc';
};
export default run;

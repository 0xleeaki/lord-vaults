import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';
import {routers, tokens} from './known_contracts';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creator} = await getNamedAccounts();

  const router = await deploy('RouteRepository', {from: creator, log: true});

  // route: wex -> btcb
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wex,
    tokens.btcb,
    routers.wault,
    [tokens.wex, tokens.wbnb, tokens.btcb]
  );

  // route: btcb -> wex
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.btcb,
    tokens.wex,
    routers.wault,
    [tokens.btcb, tokens.wbnb, tokens.wex]
  );

  // route: wex -> eth
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wex,
    tokens.eth,
    routers.wault,
    [tokens.wex, tokens.wbnb, tokens.eth]
  );

  // route: eth -> wex
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.eth,
    tokens.wex,
    routers.wault,
    [tokens.eth, tokens.wbnb, tokens.wex]
  );

  // route: wex -> busd
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wex,
    tokens.busd,
    routers.wault,
    [tokens.wex, tokens.wbnb, tokens.busd]
  );

  // route: busd -> wex
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.busd,
    tokens.wex,
    routers.wault,
    [tokens.busd, tokens.wbnb, tokens.wex]
  );

  // route: wex -> usdt
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wex,
    tokens.usdt,
    routers.wault,
    [tokens.wex, tokens.usdt]
  );

  // route: usdt -> wex
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.usdt,
    tokens.wex,
    routers.wault,
    [tokens.usdt, tokens.wex]
  );

  // route: wex -> wbnb
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wex,
    tokens.wbnb,
    routers.wault,
    [tokens.wex, tokens.wbnb]
  );

  // route: wbnb -> wex
  await execute(
    'RouteRepository',
    {from: creator, log: true},
    'addRoute',
    tokens.wbnb,
    tokens.wex,
    routers.wault,
    [tokens.wbnb, tokens.wex]
  );
};

run.tags = ['bsc', 'routers'];

run.skip = async (hre) => {
  return hre.network.name !== 'bsc';
};
export default run;

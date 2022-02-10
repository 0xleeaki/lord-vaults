import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import {routers, tokens} from './known_contracts';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creatorpoly} = await getNamedAccounts();

  await deploy('RouteRepository', {from: creatorpoly, log: true});

  // route: quick -> weth
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.quick,
    tokens.weth,
    routers.quickswap,
    [tokens.quick, tokens.wmatic, tokens.weth]
  );

  // route: weth -> quick
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.weth,
    tokens.quick,
    routers.quickswap,
    [tokens.weth, tokens.wmatic, tokens.quick]
  );

  // route: quick -> usdc
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.quick,
    tokens.usdc,
    routers.quickswap,
    [tokens.quick, tokens.wmatic, tokens.usdc]
  );

  // route: usdc -> quick
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.usdc,
    tokens.quick,
    routers.quickswap,
    [tokens.usdc, tokens.wmatic, tokens.quick]
  );

  // route: wexpoly -> wmatic
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.wexpoly,
    tokens.wmatic,
    routers.wault,
    [tokens.wexpoly, tokens.wmatic]
  );

  // route: wmatic -> wexpoly
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.wmatic,
    tokens.wexpoly,
    routers.wault,
    [tokens.wmatic, tokens.wexpoly]
  );

  // route: wexpoly -> usdc
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.wexpoly,
    tokens.usdc,
    routers.wault,
    [tokens.wexpoly, tokens.usdc]
  );

  // route: usdc -> wexpoly
  await execute(
    'RouteRepository',
    {from: creatorpoly, log: true},
    'addRoute',
    tokens.usdc,
    tokens.wexpoly,
    routers.wault,
    [tokens.usdc, tokens.wexpoly]
  );
};

run.tags = ['matic', 'routers'];

run.skip = async (hre) => {
  return hre.network.name !== 'matic';
};
export default run;

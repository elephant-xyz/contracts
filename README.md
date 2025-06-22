# vMahout – Hardhat project

This repo contains the upgradeable `VMahout.sol` ERC-20 governance token and the Hardhat workflow to deploy and maintain it.

## Prerequisites
1. Node >= 18
2. `npm install` (installs Hardhat, OpenZeppelin, etc.)
3. Environment variables (only required when you deploy to a public network). Create a `.env` and fill in the values you need:
   ```dotenv
   # RPC endpoints
   AMOY_RPC_URL="https://..."
   POLYGON_MAINNET_RPC_URL="https://..."

   # Keys / secrets
   KMS_KEY_ID="..."           # only if you use @rumblefishdev/hardhat-kms-signer
   ETHERSCAN_API_KEY="..."   # or POLYGONSCAN_API_KEY
   ```
   When the RPC variables are undefined Hardhat will ignore those networks, so local development works with no extra config.

## Running the tests
```bash
npm test          # compiles, then executes contracts + task tests on an in-memory chain
```
All unit-tests must pass (including the deploy/upgrade tasks under `test/VMahoutTasks.ts`).

## Local deployment (Hardhat node)
```bash
# 1) start a local chain in another terminal
npx hardhat node

# 2) deploy vMahout to that chain (use one of the default accounts as minter)
#    The deployer automatically becomes DEFAULT_ADMIN_ROLE & UPGRADER_ROLE
npx hardhat deploy-vmahout --minter 0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73 --network localhost
```
The task prints the proxy address. You can now interact with it or run the upgrade task.

## Deploying to a public network (e.g. Polygon)
```bash
# assumes POLYGON_MAINNET_RPC_URL & ETHERSCAN_API_KEY are set
npx hardhat deploy-vmahout \
  --minter 0x1234...dead \
  --network polygon
```
Behaviour:
* Deploys a UUPS proxy
* The deployer address becomes defaultAdmin & upgrader
* Verifies both the implementation and the proxy on Polygonscan automatically

## Upgrading an existing proxy
```bash
# Example: upgrade on Polygon
npx hardhat upgrade-vmahout \
  --proxy 0xProxyAddressHere \
  --network polygon

# Example: upgrade and grant MINTER_ROLE to a new address
npx hardhat upgrade-vmahout \
  --proxy 0xProxyAddressHere \
  --minter 0x1234...dead \
  --network polygon
```
The task force-imports the proxy into a fresh local manifest (handy on a new environment), performs the upgrade, then re-verifies the new implementation (and the proxy if necessary). If a `--minter` address is provided, the task will also grant the MINTER_ROLE to that address after the upgrade.

## Helpful Hardhat commands
```bash
npx hardhat clean         # wipe artifacts
npx hardhat compile       # compile only
npx hardhat help          # list all available tasks (including deploy-vmahout & upgrade-vmahout)
```

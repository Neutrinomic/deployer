# ICRC Ledger deployer

Allows anyone to deploy ICRC ledgers at the cost of 7 ICP (one time fee)

Blast for deploying ledgers: https://jglts-daaaa-aaaai-qnpma-cai.ic0.app/777.983b83715883dfd5f8c2b4ec2bf1087c20b91c5cd3d57071fcff730b

Features:
- The deployed ledger uses NNS blessed versions
- Deployment requires one time 7 ICP fee - it gets sent to Neutrinite DAO treasury
- The initial ledger configuration can't be changed.
- Ledgers can only be NNS blessed SNSW builds
- Ledgers can be upgraded only to other NNS blessed versions
- Ledgers come with 50T cycles
- Archive canisters will take 20T cycles once spawned (after 1000 transactions)
- Users are responsible for refilling their ledger canisters with cycles
- Deployer source code here https://github.com/Neutrinomic/deployer
- The deployer will be governed by Neutrinite DAO

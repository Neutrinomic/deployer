#!/bin/sh
rm message.json
export PEM_FILE="$HOME/.config/dfx/identity/$(dfx identity whoami)/identity.pem"

dfx build --network ic deployer
quill sns make-upgrade-canister-proposal 824f1a1df2652fb26c0fe1c03ab5ce69f2561570fb4d042cdc32dcb4604a4f03 --pem-file $PEM_FILE --target-canister-id toj6n-haaaa-aaaal-qdika-cai --canister-ids-file sns_canister_ids.json --summary-path proposal_summary.md --mode upgrade --wasm-path ./.dfx/ic/canisters/deployer/deployer.wasm.gz > message.json 

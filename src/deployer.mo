import Ledger "./services/ledger";
import IC "./services/ic";
import SNSWasm "./services/snswasm";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import Vector "mo:vector";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";
import Map "mo:map/Map";
import { phash } "mo:map/Map";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Debug "mo:base/Debug";

actor class Self() = this {


    // DID here, will need to be refreshed when it changes
    // https://github.com/dfinity/ic-js/blob/b037fe18467d85f9f59716847c32e4ce1a4d5b8e/packages/ledger-icrc/candid/icrc_ledger.did#L128
    private let ic : IC.Self = actor ("aaaaa-aa");
    private let snswasm : SNSWasm.Self = actor ("qaa6y-5yaaa-aaaaa-aaafa-cai");

    stable let steps = Vector.new<SNSWasm.ListUpgradeStep>();

    type Can = {
        canister_id : Principal;
        initarg_request : InitArgsRequested;
    };

    type Account = {
        canisters : Vector.Vector<Can>;
    };

    type AccountShared = {
        canisters : [Can];
    };

    /*
    Example meta:

    record {
      "icrc1:logo";
      variant {
        Text = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAKAAAACgCAYAAACLz2ctAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAKIBJREFUeJztnXd8FNX6/73fe3/fnyh=="
      };
    };
    record { "icrc1:decimals"; variant { Nat = 8 : nat } };
    record { "icrc1:name"; variant { Text = "Neutrinite" } };
    record { "icrc1:symbol"; variant { Text = "NTN" } };
    record { "icrc1:fee"; variant { Nat = 10_000 : nat } };
    record { "icrc1:max_memo_length"; variant { Nat = 32 : nat } };
    */

    public type InitArgsRequested = {
        token_symbol : Text; // max 7 chars
        transfer_fee : Nat;
        token_name : Text;
        metadata : [(Text, Ledger.MetadataValue)]; // needs to be fixed
        minting_account : Ledger.Account;
        initial_balances : [(Ledger.Account, Nat)];
        fee_collector_account : ?Ledger.Account;
    };

    public type InitArgsSimplified = InitArgsRequested and {
        decimals : ?Nat8; // fix to 8
        maximum_number_of_accounts : ?Nat64; //28_000_000
        accounts_overflow_trim_quantity : ?Nat64; // 100_000
        feature_flags : ?{ icrc2 : Bool };
    };

    stable let canisters = Map.new<Principal, Account>();

    private func get_upgrade_steps() : async () {
        let starting_at : ?SNSWasm.SnsVersion = if (Vector.size(steps) == 0) null else Vector.last(steps).version;

        let rez = await snswasm.list_upgrade_steps({
            limit = 100;
            starting_at;
            sns_governance_canister_id = null;
        });

        ignore Timer.setTimer(#seconds(3600 * 24), get_upgrade_steps);

        label add_steps for (step in rez.steps.vals()) {
            if (step.version == starting_at) continue add_steps;
            Vector.add(steps, step);
        };
    };

    ignore Timer.setTimer(#seconds 1, get_upgrade_steps);

    public query ({ caller }) func get_steps() : async [SNSWasm.ListUpgradeStep] {
        Vector.toArray(steps);
    };

    private func create_canister() : async Principal {
        try {
            // Create canister
            Cycles.add(4_000_000_000_000);
            let { canister_id } = await ic.create_canister({
                settings = ?{
                    controllers = ?[Principal.fromActor(this)];
                    freezing_threshold = ?2_000_000_000_000;
                    memory_allocation = ?1000000000; // 1gb
                    compute_allocation = null;
                    reserved_cycles_limit = ?0;
                }:?IC.canister_settings;
            sender_canister_version = null});

            canister_id;
        } catch (e) {
            return Debug.trap("Canister creation failed " # debug_show Error.message(e));
        };
    };


    public query ({ caller }) func get_account() : async Result.Result<AccountShared, Text> {
        assert Principal.isController(caller);
        let ?acc = Map.get(canisters, phash, caller) else return #err("No canister found");
        #ok({
            canisters = Vector.toArray(acc.canisters);
        });
    };

    private func add_canister_to_account({
        canister_id : Principal;
        caller : Principal;
        initarg_request : InitArgsRequested;
    }) : () {

        let account = switch (Map.get(canisters, phash, caller)) {
            case (?acc) {
                acc;
            };
            case (null) {
                let acc = { canisters = Vector.new<Can>() };
                Map.set(canisters, phash, caller, acc);
                acc;
            };
        };

        Vector.add(account.canisters, { canister_id; initarg_request });
    };

    public shared ({ caller }) func install(req_args : InitArgsRequested) : async Result.Result<Principal, Text> {

        assert Principal.isController(caller);

        if (Text.size(req_args.token_symbol) > 7) return #err("Token symbol too long");
        if (Text.size(req_args.token_name) > 32) return #err("Token name too long");

        let init_args : InitArgsSimplified = {
            req_args with
            decimals = ?8 : ?Nat8;
            maximum_number_of_accounts = ?28_000_000 : ?Nat64;
            accounts_overflow_trim_quantity = ?100_000 : ?Nat64;
            feature_flags = ?{ icrc2 = true };
        };

        let ?last_version = Vector.last(steps).version else return #err("No upgrade steps available");
        let last_ledger_hash = last_version.ledger_wasm_hash;

        // Get latest wasm
        let wasm_resp = await snswasm.get_wasm({ hash = last_ledger_hash });
        let ?wasm_ver = wasm_resp.wasm else return #err("No blessed wasm available");
        let wasm = wasm_ver.wasm;

        // Make ledger initial arguments
        // Ledgers won't show some of its options, so we will not allow them to be set, which will guarantee they are good.
        // Settings same as SNS ledgers - https://github.com/dfinity/ic/blob/8b2d48ca3571d5c09834cba4f90aa2153d88fbe8/rs/sns/init/src/lib.rs#L662

        let archive_options : Ledger.ArchiveOptions = {
            num_blocks_to_archive = 1000; /// The number of blocks to archive when trigger threshold is exceeded
            trigger_threshold = 2000; /// The number of blocks which, when exceeded, will trigger an archiving operation.
            node_max_memory_size_bytes = ?(1024 * 1024 * 1024);
            max_message_size_bytes = ?(128 * 1024);
            cycles_for_archive_creation = ?10_000_000_000_000;
            controller_id = Principal.fromActor(this);
            max_transactions_per_response = null;
        };

        let args : Ledger.LedgerArg = #Init({
            init_args with
            archive_options;
            max_memo_length = ?80 : ?Nat16;
        });

        let canister_id = await create_canister();

        // Install code
        try {
            await ic.install_code({
                arg = to_candid (args);
                wasm_module = wasm;
                mode = #install;
                canister_id;
                sender_canister_version = null;
            });
        } catch (e) {
            return #err("Canister installation failed " # debug_show (Error.message(e)));
        };

        add_canister_to_account({
            canister_id;
            caller;
            initarg_request = init_args;
        });

        #ok(canister_id);

    };

};

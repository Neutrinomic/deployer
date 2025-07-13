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
import ICRCLedger "./services/icrc_ledger"; // used for payment only
import Nat8 "mo:base/Nat8";

actor class Self() = this {
    let ICP_Install_Fee = 7_0000_0000 - 1_0000;
    let CYCLES_FOR_INSTALL = 50_000_000_000_000;
    // ---
    let MIN_CYCLES_IN_DEPLOYER = 70_000_000_000_000;

    let cycleOps = Principal.fromText("5vdms-kaaaa-aaaap-aa3uq-cai");
    let cycleOps_new = Principal.fromText("cpbhu-5iaaa-aaaad-aalta-cai");

    // Only admins can install new ledgers
    // They can't change the parameters of the ledgers however or do anything else but install new ledgers and send cycles
    let admin_id = Principal.fromText("vwng4-j5dgs-e5kv2-ofyq2-hc4be-7u2fn-mmncn-u7dhj-nzkyq-vktfa-xqe");

    // DID here, will need to be refreshed when it changes
    // https://github.com/dfinity/ic-js/blob/b037fe18467d85f9f59716847c32e4ce1a4d5b8e/packages/ledger-icrc/candid/icrc_ledger.did#L128
    private let ic : IC.Self = actor ("aaaaa-aa");
    private let snswasm : SNSWasm.Self = actor ("qaa6y-5yaaa-aaaaa-aaafa-cai");

    stable let steps = Vector.new<SNSWasm.SnsVersion>();

    let ICP_ledger_id = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
    let ICP_ledger = actor (Principal.toText(ICP_ledger_id)) : ICRCLedger.Self;
    let ICP_treasury_account : ICRCLedger.Account = {owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"); subaccount = null};

    type ArchiveOptions = {
      num_blocks_to_archive : Nat64;
      max_transactions_per_response : ?Nat64;
      trigger_threshold : Nat64;
      max_message_size_bytes : ?Nat64;
      cycles_for_archive_creation : ?Nat64;
      node_max_memory_size_bytes : ?Nat64;
      controller_id : Principal;
      more_controller_ids : ?[Principal];
    };

    type Can = {
        canister_id : Principal;
        var hash : Blob;
        initarg_request : ReqArgsIncluded;
        upgradearg : Ledger.UpgradeArgs;
    };

    type CanShared = {
        canister_id : Principal;
        hash : Blob;
        initarg_request : ReqArgsIncluded;
        upgradearg : Ledger.UpgradeArgs;
    };

    type Account = {
        canisters : Vector.Vector<Can>;
    };

    type AccountShared = {
        canisters : [CanShared];
    };

    type ReqArgsIncluded = {
        token_symbol : Text; // max 7 chars
        transfer_fee : Nat;
        token_name : Text;
        minting_account : Ledger.Account;
        initial_balances : [(Ledger.Account, Nat)];
        fee_collector_account : ?Ledger.Account;
    };

    public type InitArgsRequested = ReqArgsIncluded and {
        logo: Text;
    };

    public type InitArgsSimplified = InitArgsRequested and {
        decimals : ?Nat8; // fix to 8
        maximum_number_of_accounts : ?Nat64; //28_000_000
        accounts_overflow_trim_quantity : ?Nat64; // 100_000
        feature_flags : ?{ icrc2 : Bool };
        metadata : [(Text, Ledger.MetadataValue)]; // needs to be fixed
    };

    stable let canisters = Map.new<Principal, Account>();

    private func get_upgrade_steps() : async () {
        

        let rez = await snswasm.list_upgrade_steps({
            limit = 500;
            starting_at = null;
            sns_governance_canister_id = null;
        });

        Vector.clear(steps);
        label add_steps for (step in rez.steps.vals()) {
            ignore do ? { Vector.add(steps, step.version!); }
        };
    };

    // This has to be called manually after checking if ledger init params changed
    // The admin principal can only trigger retrieval of new steps from SNSW
    // This is done after checking if the ledger init params changed
    // If no checks are done and it's automatic, this could cause new ledger installs to fail
    // and charge fees while not delivering ledgers
    public shared({caller}) func refresh_upgrade_steps() : async () {
        assert (caller == admin_id);
        await get_upgrade_steps();
    };

    public query ({ caller }) func get_steps() : async [SNSWasm.SnsVersion] {
        Vector.toArray(steps);
    };

    // When Cycleops changes, we can set them again, also setting controllers of archives as well
    public shared({caller}) func set_controllers(canister_id : Principal) : async () {
        assert (caller == admin_id);
        await ic.update_settings({
            canister_id;
            settings = {
                controllers = ?[Principal.fromActor(this), cycleOps, cycleOps_new];
                freezing_threshold = ?9331200; // 108 days
                memory_allocation = null;
                compute_allocation = null;
                reserved_cycles_limit = null;
            };
            sender_canister_version = null;
        });
    };

    public shared({caller}) func send_cycles(amount : Nat, to_canister: Principal) : async Result.Result<(), Text> {
        if (caller != admin_id) return #err("Only admins can send cycles");

        let balance = Cycles.balance();

        if (balance < amount + 5 * MIN_CYCLES_IN_DEPLOYER) return #err("Need to leave at least 5 * MIN_CYCLES_IN_DEPLOYER cycles in deployer");
   
        Cycles.add<system>(amount);
        await ic.deposit_cycles({ canister_id = to_canister });

        #ok();
    };

    private func create_canister() : async Principal {
        try {
            // Create canister
            Cycles.add(CYCLES_FOR_INSTALL);
            let { canister_id } = await ic.create_canister({
                settings = ?{
                    controllers = ?[Principal.fromActor(this), cycleOps, cycleOps_new];
                    freezing_threshold = ?9331200; // 108 days
                    memory_allocation = null;
                    compute_allocation = null;
                    reserved_cycles_limit = null;
                };
            sender_canister_version = null});

            canister_id;
        } catch (e) {
            return Debug.trap("Canister creation failed " # debug_show Error.message(e));
        };
    };


    public query ({ caller }) func get_account() : async Result.Result<AccountShared, Text> {
        
        let ?acc = Map.get(canisters, phash, caller) else return #err("No account found");
        #ok({
            canisters = Array.map<Can,CanShared>(Vector.toArray(acc.canisters), func(x) {
                { canister_id = x.canister_id; hash = x.hash; initarg_request = x.initarg_request; upgradearg = x.upgradearg }
            });
        });
    };

    private func add_canister_to_account({
        canister_id : Principal;
        caller : Principal;
        initarg_request : InitArgsRequested;
        upgradearg : Ledger.UpgradeArgs;
        hash: Blob;
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

        Vector.add(account.canisters, { canister_id; initarg_request; upgradearg; var hash });
    };

    // A caller can trigger ledger upgrade at any time, but only to NNS blessed ledger versions
    // They can't change the parameters
    public shared ({caller}) func upgrade(ledger_id : Principal) : async Result.Result<(), Text> {
        let ?acc = Map.get(canisters, phash, caller) else return #err("No account found");
        var found:?Can = null;
        label search for (can in Vector.vals(acc.canisters)) {
            if (can.canister_id == ledger_id) {
                found := ?can;
                break search;
            };
        };
        let ?can = found else return #err("No canister found");

        // find next upgrade step
        var next_step: ?SNSWasm.SnsVersion = null;
        var found_current : Bool = false;

        label search for (step in Vector.vals(steps)) {
            if (Blob.compare(step.ledger_wasm_hash, can.hash) == #equal) {
                found_current := true;
            };
            if ((found_current == true) and (Blob.compare(step.ledger_wasm_hash, can.hash) != #equal)) {
                next_step := ?step;
                break search;
            };
        };
        let ?ver = next_step else return #err("No next step found");
        let wasm_resp = await snswasm.get_wasm({ hash = ver.ledger_wasm_hash });
        let ?wasm_ver = wasm_resp.wasm else return #err("No blessed wasm available");
        let wasm = wasm_ver.wasm;
        
        let uarg:Ledger.UpgradeArgs = can.upgradearg;

        let args : Ledger.LedgerArg = #Upgrade(?uarg);
        try {
            await ic.install_code({
                arg = to_candid(args);
                wasm_module = wasm;
                mode = #upgrade(null);
                canister_id = can.canister_id;
                sender_canister_version = null;
            });
        } catch (e) {
            return #err("Canister installation failed " # debug_show (Error.message(e)));
        };

        can.hash := ver.ledger_wasm_hash;

        #ok();
    };



    public shared ({ caller }) func install(req_args : InitArgsRequested) : async Result.Result<Principal, Text> {
        if (caller != admin_id) return #err("Only admins can install new ledgers");
        if (Text.size(req_args.token_symbol) > 7) return #err("Token symbol too long");
        if (Text.size(req_args.token_name) > 32) return #err("Token name too long");
        if (Text.size(req_args.logo) < 100) return #err("Logo too small");
        if (Text.size(req_args.logo) > 30000) return #err("Logo has to be at most 30000 chars encoded");

        let init_args : InitArgsSimplified = {
            req_args with
            decimals = ?8 : ?Nat8;
            maximum_number_of_accounts = ?28_000_000 : ?Nat64;
            accounts_overflow_trim_quantity = ?100_000 : ?Nat64;
            feature_flags = ?{ icrc2 = true };
            metadata= [
                ("icrc1:logo", #Text(req_args.logo))
                ];
        };

        let version = Vector.get(steps, Vector.size(steps) - 1:Nat);
        let inst_ledger_hash = version.ledger_wasm_hash;

        // Get latest wasm
        let wasm_resp = await snswasm.get_wasm({ hash = inst_ledger_hash });
        let ?wasm_ver = wasm_resp.wasm else return #err("No blessed wasm available");
        let wasm = wasm_ver.wasm;

        // Make ledger initial arguments
        // Ledgers won't show some of its options, so we will not allow them to be set, which will guarantee they are good.
        // Settings same as SNS ledgers - https://github.com/dfinity/ic/blob/8b2d48ca3571d5c09834cba4f90aa2153d88fbe8/rs/sns/init/src/lib.rs#L662

        let archive_options : ArchiveOptions = {
            num_blocks_to_archive = 1000; /// The number of blocks to archive when trigger threshold is exceeded
            trigger_threshold = 2000; /// The number of blocks which, when exceeded, will trigger an archiving operation.
            node_max_memory_size_bytes = ?(1024 * 1024 * 1024);
            max_message_size_bytes = ?(128 * 1024);
            cycles_for_archive_creation = ?20_000_000_000_000;
            controller_id = Principal.fromActor(this);
            max_transactions_per_response = null;
            more_controller_ids = null;
        };

        let args : Ledger.LedgerArg = #Init({
            init_args with
            archive_options;
            max_memo_length = ?80 : ?Nat16;
        });

        let upgradearg : Ledger.UpgradeArgs = {
            token_symbol = ?req_args.token_symbol;
            transfer_fee = ?req_args.transfer_fee;
            metadata = ?init_args.metadata;
            maximum_number_of_accounts = init_args.maximum_number_of_accounts;
            accounts_overflow_trim_quantity = init_args.accounts_overflow_trim_quantity;
            max_memo_length = ?80;
            token_name = ?req_args.token_name;
            feature_flags = init_args.feature_flags;
            change_fee_collector = ?(switch(init_args.fee_collector_account) {
                case (?acc) #SetTo(acc);
                case (null) #Unset;
            });
        };

        // Check if this canister has enough cycles
        let balance = Cycles.balance();
        if (balance < CYCLES_FOR_INSTALL + MIN_CYCLES_IN_DEPLOYER) return #err("Not enough cycles in deployer");

        // if (not Principal.isController(caller)) switch (await ICP_ledger.icrc1_transfer({ 
        //     to = ICP_treasury_account; 
        //     fee = null; 
        //     memo = null; 
        //     from_subaccount = ?callerSubaccount(caller); 
        //     created_at_time = null; 
        //     amount = ICP_Install_Fee })) {
        //     case (#Ok(_)) ();
        //     case (#Err(e)) return #err("ICP payment error: " # debug_show(e));
        // };

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
            hash = inst_ledger_hash;
            upgradearg = upgradearg;
        });

        #ok(canister_id);

    };


    public func canister_status(request : IC.canister_status_args) : async IC.canister_status_result {
        await ic.canister_status(request)
    };

    private func callerSubaccount(p : Principal) : Blob {
        let a = Array.init<Nat8>(32, 0);
        let pa = Principal.toBlob(p);
        a[0] := Nat8.fromNat(pa.size());

        var pos = 1;
        for (x in pa.vals()) {
                a[pos] := x;
                pos := pos + 1;
            };

        Blob.fromArray(Array.freeze(a));
    };

    public shared({caller}) func refund(to: Ledger.Account) : async () {
        let from :Ledger.Account = {
            owner = Principal.fromActor(this);
            subaccount = ?callerSubaccount(caller);
        };
        let balance = await ICP_ledger.icrc1_balance_of(from);

        switch(await ICP_ledger.icrc1_transfer({
            to; 
            fee = null; 
            memo = null; 
            from_subaccount = from.subaccount; 
            created_at_time = null; 
            amount = balance - 10_000
            })) {
            case (#Ok(_)) ();
            case (#Err(e)) return Debug.trap("ICP payment error: " # debug_show(e));
        };
    }
};

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

 actor class Self() = this {

    private let ledger : Ledger.Use = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai");
    private let ic : IC.Self = actor ("aaaaa-aa");
    private let snswasm : SNSWasm.Self = actor ("qaa6y-5yaaa-aaaaa-aaafa-cai");
    

    let steps = Vector.new<SNSWasm.ListUpgradeStep>();
    var refresh_requests : Nat = 0;

    type CanisterInfo = {
        canister_id: Principal;
        locked: Bool;
    };

    // stable let canisters = Map.new<Principal, CanisterInfo>();

    private func get_upgrade_steps() : async () {
        let starting_at:?SNSWasm.SnsVersion  = if (Vector.size(steps) ==0) null else Vector.last(steps).version;

        let rez = await snswasm.list_upgrade_steps({limit= 100; starting_at; sns_governance_canister_id= null});

        refresh_requests := refresh_requests + 1;
        
        ignore Timer.setTimer(#seconds (3600*24), get_upgrade_steps);

        label add_steps for (step in rez.steps.vals()) {
            if (step.version == starting_at) continue add_steps;
            Vector.add(steps, step);
        };
    };

    ignore Timer.setTimer(#seconds 1, get_upgrade_steps);

    // public query({caller}) func get_steps() : async [SNSWasm.ListUpgradeStep] {
    //     Vector.toArray(steps)
    // };

    // public query func get_stats() : async { refresh_requests: Nat } {
    //     { refresh_requests }
    // };

    public shared({caller}) func create_canister() : async Result.Result<Principal, Text> {
        assert Principal.isController(caller);

        // if (Option.isSome(Map.get(canisters, phash, caller))) return #err("Canister already created");

        // Create canister
        Cycles.add(20_000_000_000_000);
        let {canister_id} = await ic.create_canister({settings= ?{
                controllers = ?[Principal.fromActor(this)];
                freezing_threshold = ?1_000_000_000_000;
                memory_allocation = null;
                compute_allocation = null;
            }});

       let cinfo = {
        canister_id;
        locked = false;
        }:CanisterInfo;

    //    Map.set(canisters, phash, caller, cinfo);

       #ok(canister_id);
    };

    public shared({caller}) func del() : async () {
        await ic.uninstall_code({canister_id = Principal.fromText("pdfyo-6yaaa-aaaam-abzja-cai")});
        await ic.uninstall_code({canister_id = Principal.fromText("pee62-taaaa-aaaam-abzjq-cai")});
        
    };

    // public query({caller}) func get_canister_id() : async Result.Result<Principal, Text> {
    //     assert Principal.isController(caller);
    //     let ?can_info = Map.get(canisters, phash, caller) else return #err("No canister found");
    //     #ok(can_info.canister_id);
    // };

    public shared({caller}) func install(init_args: Ledger.InitArgsSimplified, mode: {#install; #reinstall}) : async Result.Result<(), Text> {
        assert Principal.isController(caller);
        let ?last_version = Vector.last(steps).version else return #err("No upgrade steps available");
        let last_ledger_hash = last_version.ledger_wasm_hash;

        // let ?can_info = Map.get(canisters, phash, caller) else return #err("No canister found");
        // if (can_info.locked == true) return #err("Canister is locked");
        let canister_id = Principal.fromText("pdfyo-6yaaa-aaaam-abzja-cai"); //can_info.canister_id;

        // Get latest wasm
        let wasm_resp = await snswasm.get_wasm({hash = last_ledger_hash});
        let ?wasm_ver = wasm_resp.wasm else return #err("No blessed wasm available");
        let wasm = wasm_ver.wasm;

        // Make ledger initial arguments
        // Ledgers won't show some of its options, so we will not allow them to be set, which will guarantee they are good.
        let archive_options : Ledger.ArchiveOptions = {
                num_blocks_to_archive = 5000;  /// The number of blocks to archive when trigger threshold is exceeded
                trigger_threshold = 5000; /// The number of blocks which, when exceeded, will trigger an archiving operation.
                node_max_memory_size_bytes = ?(1024 * 1024 * 1024);
                max_message_size_bytes = ?(128 * 1024);
                cycles_for_archive_creation = ?10_000_000_000_000;
                controller_id = Principal.fromActor(this);
                max_transactions_per_response = null;
            };

        let args:Ledger.LedgerArg = #Init({
            init_args with
            archive_options;
            max_memo_length = null;
        });

        // Install code
        await ic.install_code({ arg = to_candid(args); wasm_module = wasm; mode; canister_id });

        #ok();

    }

 }
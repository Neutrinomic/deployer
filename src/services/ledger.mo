module {
  public type Account = { owner : Principal; subaccount : ?Subaccount };
  public type Allowance = { allowance : Nat; expires_at : ?Timestamp };
  public type AllowanceArgs = { account : Account; spender : Account };
  public type Approve = {
    fee : ?Nat;
    from : Account;
    memo : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Timestamp;
    spender : Account;
  };
  public type ApproveArgs = {
    fee : ?Nat;
    memo : ?[Nat8];
    from_subaccount : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Timestamp;
    spender : Account;
  };
  public type ApproveError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : BlockIndex };
    #BadFee : { expected_fee : Nat };
    #AllowanceChanged : { current_allowance : Nat };
    #CreatedInFuture : { ledger_time : Timestamp };
    #TooOld;
    #Expired : { ledger_time : Timestamp };
    #InsufficientFunds : { balance : Nat };
  };
  public type ApproveResult = { #Ok : BlockIndex; #Err : ApproveError };
  public type Block = Value;
  public type BlockIndex = Nat;
  public type BlockRange = { blocks : [Block] };
  public type Burn = {
    from : Account;
    memo : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Nat;
    spender : ?Account;
  };
  public type ChangeFeeCollector = { #SetTo : Account; #Unset };
  public type DataCertificate = { certificate : ?[Nat8]; hash_tree : [Nat8] };
  public type Duration = Nat64;
  public type FeatureFlags = { icrc2 : Bool };
  public type GetBlocksArgs = { start : BlockIndex; length : Nat };
  public type GetBlocksResponse = {
    certificate : ?[Nat8];
    first_index : BlockIndex;
    blocks : [Block];
    chain_length : Nat64;
    archived_blocks : [
      { callback : QueryBlockArchiveFn; start : BlockIndex; length : Nat }
    ];
  };
  public type GetTransactionsRequest = { start : TxIndex; length : Nat };
  public type GetTransactionsResponse = {
    first_index : TxIndex;
    log_length : Nat;
    transactions : [Transaction];
    archived_transactions : [
      { callback : QueryArchiveFn; start : TxIndex; length : Nat }
    ];
  };
  public type HttpRequest = {
    url : Text;
    method : Text;
    body : [Nat8];
    headers : [(Text, Text)];
  };
  public type HttpResponse = {
    body : [Nat8];
    headers : [(Text, Text)];
    status_code : Nat16;
  };
  public type InitArgs = {
    decimals : ?Nat8;
    token_symbol : Text;
    transfer_fee : Nat;
    metadata : [(Text, MetadataValue)];
    minting_account : Account;
    initial_balances : [(Account, Nat)];
    maximum_number_of_accounts : ?Nat64;
    accounts_overflow_trim_quantity : ?Nat64;
    fee_collector_account : ?Account;
    archive_options : ArchiveOptions;
    max_memo_length : ?Nat16;
    token_name : Text;
    feature_flags : ?FeatureFlags;
  };

  public type ArchiveOptions = {
      num_blocks_to_archive : Nat64;
      max_transactions_per_response : ?Nat64;
      trigger_threshold : Nat64;
      max_message_size_bytes : ?Nat64;
      cycles_for_archive_creation : ?Nat64;
      node_max_memory_size_bytes : ?Nat64;
      controller_id : Principal;
  };

  public type InitArgsSimplified = {
      decimals : ?Nat8;
      token_symbol : Text;
      transfer_fee : Nat;
      metadata : [(Text, MetadataValue)];
      minting_account : Account;
      initial_balances : [(Account, Nat)];
      maximum_number_of_accounts : ?Nat64;
      accounts_overflow_trim_quantity : ?Nat64;
      fee_collector_account : ?Account;
      token_name : Text;
      feature_flags : ?FeatureFlags;
  };


  public type LedgerArg = { #Upgrade : ?UpgradeArgs; #Init : InitArgs };
  public type Map = [(Text, Value)];
  public type MetadataValue = {
    #Int : Int;
    #Nat : Nat;
    #Blob : [Nat8];
    #Text : Text;
  };
  public type Mint = {
    to : Account;
    memo : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Nat;
  };
  public type QueryArchiveFn = shared query GetTransactionsRequest -> async TransactionRange;
  public type QueryBlockArchiveFn = shared query GetBlocksArgs -> async BlockRange;
  public type StandardRecord = { url : Text; name : Text };
  public type Subaccount = [Nat8];
  public type Timestamp = Nat64;
  public type Tokens = Nat;
  public type Transaction = {
    burn : ?Burn;
    kind : Text;
    mint : ?Mint;
    approve : ?Approve;
    timestamp : Timestamp;
    transfer : ?Transfer;
  };
  public type TransactionRange = { transactions : [Transaction] };
  public type Transfer = {
    to : Account;
    fee : ?Nat;
    from : Account;
    memo : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Nat;
    spender : ?Account;
  };
  public type TransferArg = {
    to : Account;
    fee : ?Tokens;
    memo : ?[Nat8];
    from_subaccount : ?Subaccount;
    created_at_time : ?Timestamp;
    amount : Tokens;
  };
  public type TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #BadBurn : { min_burn_amount : Tokens };
    #Duplicate : { duplicate_of : BlockIndex };
    #BadFee : { expected_fee : Tokens };
    #CreatedInFuture : { ledger_time : Timestamp };
    #TooOld;
    #InsufficientFunds : { balance : Tokens };
  };
  public type TransferFromArgs = {
    to : Account;
    fee : ?Tokens;
    spender_subaccount : ?Subaccount;
    from : Account;
    memo : ?[Nat8];
    created_at_time : ?Timestamp;
    amount : Tokens;
  };
  public type TransferFromError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientAllowance : { allowance : Tokens };
    #BadBurn : { min_burn_amount : Tokens };
    #Duplicate : { duplicate_of : BlockIndex };
    #BadFee : { expected_fee : Tokens };
    #CreatedInFuture : { ledger_time : Timestamp };
    #TooOld;
    #InsufficientFunds : { balance : Tokens };
  };
  public type TransferFromResult = {
    #Ok : BlockIndex;
    #Err : TransferFromError;
  };
  public type TransferResult = { #Ok : BlockIndex; #Err : TransferError };
  public type TxIndex = Nat;
  public type UpgradeArgs = {
    token_symbol : ?Text;
    transfer_fee : ?Nat;
    metadata : ?[(Text, MetadataValue)];
    maximum_number_of_accounts : ?Nat64;
    accounts_overflow_trim_quantity : ?Nat64;
    change_fee_collector : ?ChangeFeeCollector;
    max_memo_length : ?Nat16;
    token_name : ?Text;
    feature_flags : ?FeatureFlags;
  };
  public type Value = {
    #Int : Int;
    #Map : Map;
    #Nat : Nat;
    #Nat64 : Nat64;
    #Blob : [Nat8];
    #Text : Text;
    #Array : [Value];
  };
  public type Self = LedgerArg -> async actor {
    get_blocks : shared query GetBlocksArgs -> async GetBlocksResponse;
    get_data_certificate : shared query () -> async DataCertificate;
    get_transactions : shared query GetTransactionsRequest -> async GetTransactionsResponse;
    icrc1_balance_of : shared query Account -> async Tokens;
    icrc1_decimals : shared query () -> async Nat8;
    icrc1_fee : shared query () -> async Tokens;
    icrc1_metadata : shared query () -> async [(Text, MetadataValue)];
    icrc1_minting_account : shared query () -> async ?Account;
    icrc1_name : shared query () -> async Text;
    icrc1_supported_standards : shared query () -> async [StandardRecord];
    icrc1_symbol : shared query () -> async Text;
    icrc1_total_supply : shared query () -> async Tokens;
    icrc1_transfer : shared TransferArg -> async TransferResult;
    icrc2_allowance : shared query AllowanceArgs -> async Allowance;
    icrc2_approve : shared ApproveArgs -> async ApproveResult;
    icrc2_transfer_from : shared TransferFromArgs -> async TransferFromResult;
  };

  public type Use = actor {
    get_blocks : shared query GetBlocksArgs -> async GetBlocksResponse;
    get_data_certificate : shared query () -> async DataCertificate;
    get_transactions : shared query GetTransactionsRequest -> async GetTransactionsResponse;
    icrc1_balance_of : shared query Account -> async Tokens;
    icrc1_decimals : shared query () -> async Nat8;
    icrc1_fee : shared query () -> async Tokens;
    icrc1_metadata : shared query () -> async [(Text, MetadataValue)];
    icrc1_minting_account : shared query () -> async ?Account;
    icrc1_name : shared query () -> async Text;
    icrc1_supported_standards : shared query () -> async [StandardRecord];
    icrc1_symbol : shared query () -> async Text;
    icrc1_total_supply : shared query () -> async Tokens;
    icrc1_transfer : shared TransferArg -> async TransferResult;
    icrc2_allowance : shared query AllowanceArgs -> async Allowance;
    icrc2_approve : shared ApproveArgs -> async ApproveResult;
    icrc2_transfer_from : shared TransferFromArgs -> async TransferFromResult;
  }

}

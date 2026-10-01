///|
/// Errors reported by configuration, coding, repair, or archive validation.
pub(all) suberror ErasureError {
  InvalidConfiguration(String)
  InvalidShardCount(expected~ : Int, actual~ : Int)
  InvalidShardLength(index~ : Int, expected~ : Int, actual~ : Int)
  EmptyShard
  NotEnoughShards(required~ : Int, available~ : Int)
  SingularMatrix
  InvalidIndex(Int)
  DuplicateIndex(Int)
  InconsistentShard(Int)
  InvalidRange
  InvalidEnvelope(String)
  UnsupportedVersion(Int)
  ChecksumMismatch(Int)
  ResourceLimit(String)
  InvalidManifest(String)
}

///|
pub fn ErasureError::code(self : ErasureError) -> String {
  match self {
    InvalidConfiguration(_) => "ERASURE_CONFIG"
    InvalidShardCount(..) => "ERASURE_SHARD_COUNT"
    InvalidShardLength(..) => "ERASURE_SHARD_LENGTH"
    EmptyShard => "ERASURE_EMPTY_SHARD"
    NotEnoughShards(..) => "ERASURE_NOT_ENOUGH_SHARDS"
    SingularMatrix => "ERASURE_SINGULAR_MATRIX"
    InvalidIndex(_) => "ERASURE_INDEX"
    DuplicateIndex(_) => "ERASURE_DUPLICATE_INDEX"
    InconsistentShard(_) => "ERASURE_INCONSISTENT_SHARD"
    InvalidRange => "ERASURE_RANGE"
    InvalidEnvelope(_) => "ERASURE_ENVELOPE"
    UnsupportedVersion(_) => "ERASURE_VERSION"
    ChecksumMismatch(_) => "ERASURE_CHECKSUM"
    ResourceLimit(_) => "ERASURE_RESOURCE_LIMIT"
    InvalidManifest(_) => "ERASURE_MANIFEST"
  }
}

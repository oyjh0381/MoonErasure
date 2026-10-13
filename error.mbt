///|
/// Errors reported by configuration, coding, repair, or archive validation.
pub(all) suberror ErasureError {
  InvalidConfiguration(String)
  InvalidShardCount(expected~ : Int32, actual~ : Int32)
  InvalidShardLength(index~ : Int32, expected~ : Int32, actual~ : Int32)
  EmptyShard
  NotEnoughShards(required~ : Int32, available~ : Int32)
  SingularMatrix
  InvalidIndex(Int32)
  DuplicateIndex(Int32)
  InconsistentShard(Int32)
  InvalidRange
  InvalidEnvelope(String)
  UnsupportedVersion(Int32)
  ChecksumMismatch(Int32)
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

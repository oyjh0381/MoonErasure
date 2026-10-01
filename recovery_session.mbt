///|
struct DecoderEntry {
  selected_indices : Array[Int]
  inverse : Matrix
}

///|
/// Reuse decode matrices when many stripes have the same erasure pattern.
/// Each session owns a small bounded FIFO cache; separate sessions should be
/// used for concurrent callers. Cached matrices contain no payload bytes.
pub struct RecoverySession {
  codec : Codec
  entries : Array[DecoderEntry]
  capacity : Int
  mut next_evict : Int
  mut hits : Int
  mut misses : Int
}

///|
pub fn RecoverySession::new(
  codec : Codec,
  max_patterns? : Int = 16,
) -> RecoverySession raise ErasureError {
  if max_patterns < 1 || max_patterns > 64 {
    raise InvalidConfiguration("recovery cache must hold 1..64 patterns")
  }
  {
    codec,
    entries: [],
    capacity: max_patterns,
    next_evict: 0,
    hits: 0,
    misses: 0,
  }
}

///|
pub fn RecoverySession::cache_size(self : RecoverySession) -> Int {
  self.entries.length()
}

///|
pub fn RecoverySession::cache_hits(self : RecoverySession) -> Int {
  self.hits
}

///|
pub fn RecoverySession::cache_misses(self : RecoverySession) -> Int {
  self.misses
}

///|
fn same_indices(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index = 0; index < left.length(); index = index + 1 {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
/// Reconstruct with the same validation as `Codec::reconstruct`. Data-only
/// stripes skip matrix work and do not alter cache counters. Cache misses
/// calculate a dense inverse once and reuse it on subsequent matching stripes.
pub fn RecoverySession::reconstruct(
  self : RecoverySession,
  shards : Array[Bytes?],
) -> Array[Bytes] raise ErasureError {
  if shards.length() != self.codec.total_count() {
    raise InvalidShardCount(expected=self.codec.total_count(), actual=shards.length())
  }
  let flags : Array[Bool] = []
  for shard in shards {
    flags.push(shard is Some(_))
  }
  let plan = self.codec.plan(flags)
  if !plan.recoverable() || !plan.needs_decode() {
    return self.codec.reconstruct(shards)
  }
  let selected = plan.selected_indices()
  for entry in self.entries {
    if same_indices(entry.selected_indices, selected) {
      let result = self.codec.reconstruct_with_decoder(shards, Some(entry.inverse))
      self.hits = self.hits + 1
      return result
    }
  }
  let inverse = self.codec.generator.selected_rows(selected).inverse(self.codec.field)
  let result = self.codec.reconstruct_with_decoder(shards, Some(inverse))
  self.misses = self.misses + 1
  let entry = { selected_indices: selected, inverse }
  if self.entries.length() < self.capacity {
    self.entries.push(entry)
  } else {
    self.entries[self.next_evict] = entry
    self.next_evict = (self.next_evict + 1) % self.capacity
  }
  result
}

///|
/// A same-size replacement of one data shard in a consistent old codeword.
pub(all) struct DataShardUpdate {
  index : Int32
  old_data : Bytes
  new_data : Bytes
}

///|
/// Apply old XOR new deltas to parity, without reading unchanged data shards.
/// Returns detached parity; neither inputs nor caller data slots are modified.
/// All shapes and indices are validated before calculation. The caller must
/// supply old data and parity from the same valid generation and persist the
/// new data plus parity together. This operation cannot verify that premise.
pub fn Codec::update_parity(
  self : Codec,
  parity : Array[Bytes],
  changes : Array[DataShardUpdate],
) -> Array[Bytes] raise ErasureError {
  if parity.length() != self.parity_count {
    raise InvalidShardCount(expected=self.parity_count, actual=parity.length())
  }
  let length = parity[0].length()
  self.check_length(length)
  for row = 1; row < parity.length(); row = row + 1 {
    if parity[row].length() != length {
      raise InvalidShardLength(
        index=self.data_count + row,
        expected=length,
        actual=parity[row].length(),
      )
    }
  }
  if changes.length() > self.data_count {
    raise ResourceLimit("data update count exceeds codec dimensions")
  }
  let seen = Array::make(self.data_count, false)
  for change in changes {
    if change.index < 0 || change.index >= self.data_count {
      raise InvalidIndex(change.index)
    }
    if seen[change.index] {
      raise DuplicateIndex(change.index)
    }
    seen[change.index] = true
    if change.old_data.length() != length {
      raise InvalidShardLength(
        index=change.index,
        expected=length,
        actual=change.old_data.length(),
      )
    }
    if change.new_data.length() != length {
      raise InvalidShardLength(
        index=change.index,
        expected=length,
        actual=change.new_data.length(),
      )
    }
  }
  let output : Array[Bytes] = []
  for row = 0; row < self.parity_count; row = row + 1 {
    let bytes = parity[row].to_array()
    for change in changes {
      let coefficient = self.generator.cells[self.data_count + row][change.index]
      if coefficient != 0 {
        for position = 0; position < length; position = position + 1 {
          let delta = change.old_data[position].to_int() ^
            change.new_data[position].to_int()
          if delta != 0 {
            bytes[position] = (bytes[position].to_int() ^
            self.field.multiply(coefficient, delta)).to_byte()
          }
        }
      }
    }
    output.push(Bytes::from_array(bytes))
  }
  output
}

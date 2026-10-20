///|
/// Nonempty, same-length old/new byte range within one data shard.
pub(all) struct DataRangeUpdate {
  index : Int32
  offset : Int32
  old_data : Bytes
  new_data : Bytes
}

///|
/// Update parity from only modified data ranges. Ranges in the same data
/// shard must not overlap; input order does not matter. Parity is copied in
/// full, so output cost remains O(m*L). All inputs must share one old generation.
pub fn Codec::update_parity_ranges(
  self : Codec,
  parity : Array[Bytes],
  changes : Array[DataRangeUpdate],
  max_ranges~ : Int32 = 4096,
  max_changed_bytes~ : Int32 = 1048576,
) -> Array[Bytes] raise ErasureError {
  if parity.length() != self.parity_count {
    raise InvalidShardCount(expected=self.parity_count, actual=parity.length())
  }
  let length = parity[0].length()
  self.check_length(length)
  for row, shard in parity {
    if shard.length() != length {
      raise InvalidShardLength(
        index=self.data_count + row,
        expected=length,
        actual=shard.length(),
      )
    }
  }
  if max_ranges < 0 || changes.length() > max_ranges || max_changed_bytes < 0 {
    raise ResourceLimit("range update budget")
  }
  let intervals : Array[(Int32, Int32, Int32)] = []
  let mut changed_bytes = 0
  for change in changes {
    if change.index < 0 || change.index >= self.data_count {
      raise InvalidIndex(change.index)
    }
    let count = change.old_data.length()
    if count == 0 ||
      change.offset < 0 ||
      count > length ||
      change.offset > length - count {
      raise InvalidRange
    }
    if change.new_data.length() != count {
      raise InvalidShardLength(
        index=change.index,
        expected=count,
        actual=change.new_data.length(),
      )
    }
    if count > max_changed_bytes - changed_bytes {
      raise ResourceLimit("changed byte budget")
    }
    changed_bytes += count
    intervals.push((change.index, change.offset, change.offset + count))
  }
  intervals.sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else if a.1 < b.1 {
      -1
    } else if a.1 > b.1 {
      1
    } else {
      0
    }
  })
  for i = 1; i < intervals.length(); i = i + 1 {
    if intervals[i].0 == intervals[i - 1].0 &&
      intervals[i].1 < intervals[i - 1].2 {
      raise InvalidRange
    }
  }
  let result : Array[Bytes] = []
  for row = 0; row < self.parity_count; row = row + 1 {
    let output = parity[row].to_array()
    for change in changes {
      let coefficient = self.generator.cells[self.data_count + row][change.index]
      for i = 0; i < change.old_data.length(); i = i + 1 {
        let delta = change.old_data[i].to_int() ^ change.new_data[i].to_int()
        if delta != 0 && coefficient != 0 {
          let at = change.offset + i
          output[at] = (output[at].to_int() ^
          self.field.multiply(coefficient, delta)).to_byte()
        }
      }
    }
    result.push(Bytes::from_array(output))
  }
  result
}

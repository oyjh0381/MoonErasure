///|
// Coefficients expressing one output row directly in the selected input basis.
fn Codec::selected_coefficients(
  self : Codec,
  index : Int32,
  decoder : Matrix?,
) -> Array[Int32] {
  match decoder {
    None => self.generator.cells[index]
    Some(inverse) => {
      if index < self.data_count {
        return inverse.cells[index]
      }
      let coefficients = Array::make(self.data_count, 0)
      for inner = 0; inner < self.data_count; inner = inner + 1 {
        let factor = self.generator.cells[index][inner]
        if factor != 0 {
          for column = 0; column < self.data_count; column = column + 1 {
            coefficients[column] = coefficients[column] ^
              self.field.multiply(factor, inverse.cells[inner][column])
          }
        }
      }
      coefficients
    }
  }
}

///|
fn Codec::selected_byte(
  self : Codec,
  coefficients : Array[Int32],
  selected : Array[Bytes],
  position : Int32,
) -> Byte {
  let mut value = 0
  for column = 0; column < self.data_count; column = column + 1 {
    if coefficients[column] != 0 {
      value = value ^
        self.field.multiply(
          coefficients[column],
          selected[column][position].to_int(),
        )
    }
  }
  value.to_byte()
}

///|
/// Return only the requested shards, detached and in request order. Both data
/// and parity indices are supported. Unrequested missing shards are not built.
/// For a nonempty request, at least k known-intact shards must be supplied.
/// Extra supplied shards are checked for consistency with the selected k.
/// An empty request validates shapes and indices but does no consistency work.
pub fn Codec::reconstruct_selected(
  self : Codec,
  shards : Array[Bytes?],
  requested : Array[Int32],
) -> Array[Bytes] raise ErasureError {
  if shards.length() != self.total_count() {
    raise InvalidShardCount(expected=self.total_count(), actual=shards.length())
  }
  if requested.length() > self.total_count() {
    raise ResourceLimit("requested shard count exceeds codec dimensions")
  }
  let wanted = Array::make(self.total_count(), false)
  for index in requested {
    if index < 0 || index >= self.total_count() {
      raise InvalidIndex(index)
    }
    if wanted[index] {
      raise DuplicateIndex(index)
    }
    wanted[index] = true
  }
  let flags = Array::make(self.total_count(), false)
  let mut length = -1
  for index = 0; index < shards.length(); index = index + 1 {
    if shards[index] is Some(shard) {
      if length == -1 {
        length = shard.length()
        self.check_length(length)
      } else if shard.length() != length {
        raise InvalidShardLength(index~, expected=length, actual=shard.length())
      }
      flags[index] = true
    }
  }
  if requested.is_empty() {
    return []
  }
  let plan = self.plan(flags)
  if !plan.recoverable() {
    raise NotEnoughShards(required=self.data_count, available=plan.available())
  }
  let indices = plan.selected_indices()
  let selected_flags = Array::make(self.total_count(), false)
  let selected : Array[Bytes] = []
  for index in indices {
    selected_flags[index] = true
    match shards[index] {
      Some(bytes) => selected.push(bytes)
      None =>
        raise NotEnoughShards(
          required=self.data_count,
          available=selected.length(),
        )
    }
  }
  let decoder = if plan.needs_decode() {
    Some(self.generator.selected_rows(indices).inverse(self.field))
  } else {
    None
  }
  // Validate surplus evidence without allocating every missing data/parity row.
  for index = 0; index < shards.length(); index = index + 1 {
    if !selected_flags[index] {
      if shards[index] is Some(bytes) {
        let coefficients = self.selected_coefficients(index, decoder)
        for position = 0; position < length; position = position + 1 {
          if self.selected_byte(coefficients, selected, position) !=
            bytes[position] {
            raise InconsistentShard(index)
          }
        }
      }
    }
  }
  let output : Array[Bytes] = []
  for index in requested {
    match shards[index] {
      Some(bytes) => output.push(copy_shard(bytes))
      None => {
        let coefficients = self.selected_coefficients(index, decoder)
        let bytes = Array::make(length, b'\x00')
        for position = 0; position < length; position = position + 1 {
          bytes[position] = self.selected_byte(coefficients, selected, position)
        }
        output.push(Bytes::from_array(bytes))
      }
    }
  }
  output
}

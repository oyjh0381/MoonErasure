///|
/// A systematic GF(256) codec. The first `data_count` shards are unchanged data;
/// the following `parity_count` shards are computed redundancy.
pub struct Codec {
  data_count : Int
  parity_count : Int
  max_encoded_bytes : Int
  generator : Matrix
  field : Field
}

///|
pub fn Codec::new(
  data_count : Int,
  parity_count : Int,
  max_encoded_bytes? : Int = 16_777_216,
) -> Codec raise ErasureError {
  if data_count < 1 || data_count > 255 || parity_count < 1 ||
    parity_count > 255 || data_count > 256 - parity_count {
    raise InvalidConfiguration("require 1..255 data/parity shards, total <= 256")
  }
  if max_encoded_bytes < data_count + parity_count ||
    max_encoded_bytes > 268_435_456 {
    raise InvalidConfiguration("encoded byte budget must fit one byte per shard and be <= 256 MiB")
  }
  let field = Field::new()
  let generator = systematic_matrix(data_count, data_count + parity_count, field)
  { data_count, parity_count, max_encoded_bytes, generator, field }
}

///|
pub fn Codec::data_count(self : Codec) -> Int {
  self.data_count
}

///|
pub fn Codec::parity_count(self : Codec) -> Int {
  self.parity_count
}

///|
pub fn Codec::total_count(self : Codec) -> Int {
  self.data_count + self.parity_count
}

///|
pub fn Codec::max_shard_bytes(self : Codec) -> Int {
  self.max_encoded_bytes / self.total_count()
}

///|
fn Codec::check_length(self : Codec, length : Int) -> Unit raise ErasureError {
  if length < 1 {
    raise EmptyShard
  }
  if length > self.max_shard_bytes() {
    raise ResourceLimit("shard length exceeds encoded byte budget")
  }
}

///|
fn Codec::check_data(self : Codec, data : Array[Bytes]) -> Int raise ErasureError {
  if data.length() != self.data_count {
    raise InvalidShardCount(expected=self.data_count, actual=data.length())
  }
  let length = data[0].length()
  self.check_length(length)
  for index = 1; index < data.length(); index = index + 1 {
    if data[index].length() != length {
      raise InvalidShardLength(
        index=index,
        expected=length,
        actual=data[index].length(),
      )
    }
  }
  length
}

///|
fn copy_shard(source : Bytes) -> Bytes {
  Bytes::from_array(source.to_array())
}

///|
/// Compute parity without changing the caller's data shards.
pub fn Codec::encode(self : Codec, data : Array[Bytes]) -> Array[Bytes] raise ErasureError {
  let length = self.check_data(data)
  let parity : Array[Bytes] = []
  for row = self.data_count; row < self.total_count(); row = row + 1 {
    let result = Array::make(length, b'\x00')
    for column = 0; column < self.data_count; column = column + 1 {
      let coefficient = self.generator.cells[row][column]
      if coefficient != 0 {
        let source = data[column]
        for position = 0; position < length; position = position + 1 {
          result[position] = (
            result[position].to_int() ^
            self.field.multiply(coefficient, source[position].to_int())
          ).to_byte()
        }
      }
    }
    parity.push(Bytes::from_array(result))
  }
  parity
}

///|
/// Return detached data followed by parity shards.
pub fn Codec::encode_all(
  self : Codec,
  data : Array[Bytes],
) -> Array[Bytes] raise ErasureError {
  let parity = self.encode(data)
  let output : Array[Bytes] = []
  for shard in data {
    output.push(copy_shard(shard))
  }
  for shard in parity {
    output.push(shard)
  }
  output
}

///|
/// Check whether every supplied parity shard agrees with the data shards.
pub fn Codec::verify(
  self : Codec,
  shards : Array[Bytes],
) -> Bool raise ErasureError {
  if shards.length() != self.total_count() {
    raise InvalidShardCount(expected=self.total_count(), actual=shards.length())
  }
  let data : Array[Bytes] = []
  for index = 0; index < self.data_count; index = index + 1 {
    data.push(shards[index])
  }
  let parity = self.encode(data)
  for index = 0; index < self.parity_count; index = index + 1 {
    if shards[self.data_count + index] != parity[index] {
      return false
    }
  }
  true
}

///|
/// Reconstruct every erased shard from any `data_count` intact shards.
/// Present shards are cross-checked against the reconstructed codeword.
/// Exactly `data_count` present shards provide no spare evidence to detect an
/// unknown corrupt byte; validate integrity envelopes before calling this API.
pub fn Codec::reconstruct(
  self : Codec,
  shards : Array[Bytes?],
) -> Array[Bytes] raise ErasureError {
  if shards.length() != self.total_count() {
    raise InvalidShardCount(expected=self.total_count(), actual=shards.length())
  }
  let selected_indices : Array[Int] = []
  let selected_shards : Array[Bytes] = []
  let mut available = 0
  let mut length = -1
  for index = 0; index < shards.length(); index = index + 1 {
    match shards[index] {
      Some(shard) => {
        if length == -1 {
          length = shard.length()
          self.check_length(length)
        } else if shard.length() != length {
          raise InvalidShardLength(
            index=index,
            expected=length,
            actual=shard.length(),
          )
        }
        available = available + 1
        if selected_indices.length() < self.data_count {
          selected_indices.push(index)
          selected_shards.push(shard)
        }
      }
      None => ()
    }
  }
  if available < self.data_count {
    raise NotEnoughShards(required=self.data_count, available~)
  }
  let data : Array[Bytes] = []
  let mut all_data_present = true
  for index = 0; index < self.data_count; index = index + 1 {
    if shards[index] is None {
      all_data_present = false
    }
  }
  if all_data_present {
    for index = 0; index < self.data_count; index = index + 1 {
      match shards[index] {
        Some(shard) => data.push(copy_shard(shard))
        None => raise NotEnoughShards(required=self.data_count, available~)
      }
    }
  } else {
    let decoder = self.generator.selected_rows(selected_indices).inverse(self.field)
    for row = 0; row < self.data_count; row = row + 1 {
      let result = Array::make(length, b'\x00')
      for column = 0; column < self.data_count; column = column + 1 {
        let coefficient = decoder.cells[row][column]
        if coefficient != 0 {
          let source = selected_shards[column]
          for position = 0; position < length; position = position + 1 {
            result[position] = (
              result[position].to_int() ^
              self.field.multiply(coefficient, source[position].to_int())
            ).to_byte()
          }
        }
      }
      data.push(Bytes::from_array(result))
    }
  }
  let result = self.encode_all(data)
  for index = 0; index < shards.length(); index = index + 1 {
    match shards[index] {
      Some(shard) =>
        if result[index] != shard {
          raise InconsistentShard(index)
        }
      None => ()
    }
  }
  result
}

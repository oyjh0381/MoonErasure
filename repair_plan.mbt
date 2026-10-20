///|
/// A deterministic preflight for a pattern of present and erased shards.
/// It does not read shard bytes or make an integrity assertion.
pub struct RepairPlan {
  required : Int32
  available : Int32
  priv selected_indices : Array[Int32]
  priv missing_data_indices : Array[Int32]
  priv missing_parity_indices : Array[Int32]
}

///|
pub fn RepairPlan::required(self : RepairPlan) -> Int32 {
  self.required
}

///|
pub fn RepairPlan::available(self : RepairPlan) -> Int32 {
  self.available
}

///|
pub fn RepairPlan::recoverable(self : RepairPlan) -> Bool {
  self.available >= self.required
}

///|
pub fn RepairPlan::minimum_additional_shards(self : RepairPlan) -> Int32 {
  if self.recoverable() {
    0
  } else {
    self.required - self.available
  }
}

///|
pub fn RepairPlan::needs_decode(self : RepairPlan) -> Bool {
  self.missing_data_indices.length() > 0
}

///|
pub fn RepairPlan::selected_indices(self : RepairPlan) -> Array[Int32] {
  let result : Array[Int32] = []
  for index in self.selected_indices {
    result.push(index)
  }
  result
}

///|
pub fn RepairPlan::missing_data_indices(self : RepairPlan) -> Array[Int32] {
  let result : Array[Int32] = []
  for index in self.missing_data_indices {
    result.push(index)
  }
  result
}

///|
pub fn RepairPlan::missing_parity_indices(self : RepairPlan) -> Array[Int32] {
  let result : Array[Int32] = []
  for index in self.missing_parity_indices {
    result.push(index)
  }
  result
}

///|
/// Report the first `k` present shards chosen by deterministic index order.
/// Storage adapters can fetch additional shards before allocating decode work.
pub fn Codec::plan(
  self : Codec,
  present : Array[Bool],
) -> RepairPlan raise ErasureError {
  if present.length() != self.total_count() {
    raise InvalidShardCount(
      expected=self.total_count(),
      actual=present.length(),
    )
  }
  let selected_indices : Array[Int32] = []
  let missing_data_indices : Array[Int32] = []
  let missing_parity_indices : Array[Int32] = []
  let mut available = 0
  for index = 0; index < present.length(); index = index + 1 {
    if present[index] {
      available = available + 1
      if selected_indices.length() < self.data_count() {
        selected_indices.push(index)
      }
    } else if index < self.data_count() {
      missing_data_indices.push(index)
    } else {
      missing_parity_indices.push(index)
    }
  }
  {
    required: self.data_count(),
    available,
    selected_indices,
    missing_data_indices,
    missing_parity_indices,
  }
}

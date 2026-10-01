///|
/// A deterministic preflight for a pattern of present and erased shards.
/// It does not read shard bytes or make an integrity assertion.
pub struct RepairPlan {
  required : Int
  available : Int
  selected_indices : Array[Int]
  missing_data_indices : Array[Int]
  missing_parity_indices : Array[Int]
}

///|
pub fn RepairPlan::required(self : RepairPlan) -> Int {
  self.required
}

///|
pub fn RepairPlan::available(self : RepairPlan) -> Int {
  self.available
}

///|
pub fn RepairPlan::recoverable(self : RepairPlan) -> Bool {
  self.available >= self.required
}

///|
pub fn RepairPlan::minimum_additional_shards(self : RepairPlan) -> Int {
  if self.recoverable() { 0 } else { self.required - self.available }
}

///|
pub fn RepairPlan::needs_decode(self : RepairPlan) -> Bool {
  self.missing_data_indices.length() > 0
}

///|
pub fn RepairPlan::selected_indices(self : RepairPlan) -> Array[Int] {
  let result : Array[Int] = []
  for index in self.selected_indices {
    result.push(index)
  }
  result
}

///|
pub fn RepairPlan::missing_data_indices(self : RepairPlan) -> Array[Int] {
  let result : Array[Int] = []
  for index in self.missing_data_indices {
    result.push(index)
  }
  result
}

///|
pub fn RepairPlan::missing_parity_indices(self : RepairPlan) -> Array[Int] {
  let result : Array[Int] = []
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
    raise InvalidShardCount(expected=self.total_count(), actual=present.length())
  }
  let selected_indices : Array[Int] = []
  let missing_data_indices : Array[Int] = []
  let missing_parity_indices : Array[Int] = []
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

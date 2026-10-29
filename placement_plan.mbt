///|
pub struct CostedRepairPlan {
  priv plan : RepairPlan
  total_cost : Int64
}

///|
pub fn CostedRepairPlan::plan(self : CostedRepairPlan) -> RepairPlan {
  self.plan
}

///|
pub fn CostedRepairPlan::total_cost(self : CostedRepairPlan) -> Int64 {
  self.total_cost
}

///|
/// Select at most k available shards by nonnegative host costs, tie-breaking
/// by shard index. Costs are abstract units, not measured network latency.
pub fn Codec::plan_costed(
  self : Codec,
  present : Array[Bool],
  costs : Array[Int64],
) -> CostedRepairPlan raise ErasureError {
  let base = self.plan(present)
  if costs.length() != self.total_count() {
    raise InvalidShardCount(expected=self.total_count(), actual=costs.length())
  }
  let candidates : Array[Int32] = []
  for i = 0; i < costs.length(); i = i + 1 {
    if costs[i] < 0L {
      raise InvalidConfiguration("negative shard cost")
    }
    if present[i] {
      candidates.push(i)
    }
  }
  candidates.sort_by((a, b) => {
    if costs[a] < costs[b] {
      -1
    } else if costs[a] > costs[b] {
      1
    } else {
      a - b
    }
  })
  let selected : Array[Int32] = []
  let mut total = 0L
  for i = 0; i < candidates.length() && i < self.data_count(); i = i + 1 {
    let index = candidates[i]
    if costs[index] > 9223372036854775807L - total {
      raise ResourceLimit("selected cost overflow")
    }
    total += costs[index]
    selected.push(index)
  }
  {
    plan: {
      required: base.required,
      available: base.available,
      selected_indices: selected,
      missing_data_indices: base.missing_data_indices.copy(),
      missing_parity_indices: base.missing_parity_indices.copy(),
    },
    total_cost: total,
  }
}

///|
pub struct DomainExposure {
  domain : String
  lost_available : Int32
  remaining : Int32
  spare : Int32
}

///|
pub fn DomainExposure::domain(self : DomainExposure) -> String {
  self.domain
}

///|
pub fn DomainExposure::lost_available(self : DomainExposure) -> Int32 {
  self.lost_available
}

///|
pub fn DomainExposure::remaining(self : DomainExposure) -> Int32 {
  self.remaining
}

///|
/// Remaining known-intact shards minus k. Negative is a recovery deficit.
pub fn DomainExposure::spare(self : DomainExposure) -> Int32 {
  self.spare
}

///|
pub fn DomainExposure::recoverable(self : DomainExposure) -> Bool {
  self.spare >= 0
}

///|
/// Evaluate losing each named failure domain independently, given the current
/// known-intact pattern. This does not certify placement independence or CRCs.
pub fn Codec::assess_domains(
  self : Codec,
  present : Array[Bool],
  placement : Array[String],
) -> Array[DomainExposure] raise ErasureError {
  let base = self.plan(present)
  if placement.length() != self.total_count() {
    raise InvalidShardCount(
      expected=self.total_count(),
      actual=placement.length(),
    )
  }
  let counts : Map[String, Int32] = Map([])
  for i = 0; i < placement.length(); i = i + 1 {
    let domain = placement[i]
    if domain.is_empty() {
      raise InvalidConfiguration("empty failure domain")
    }
    counts[domain] = counts.get(domain).unwrap_or(0) +
      (if present[i] { 1 } else { 0 })
  }
  let names : Array[String] = []
  for name, _ in counts {
    names.push(name)
  }
  names.sort_by((a, b) => a.lexical_compare(b))
  names.map(name => {
    let lost = counts[name]
    let remaining = base.available - lost
    {
      domain: name,
      lost_available: lost,
      remaining,
      spare: remaining - self.data_count(),
    }
  })
}

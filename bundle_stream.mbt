///|
/// Incremental parser for a complete bundle. Completed, checksum-validated
/// frames are returned from `push` and are not retained by the parser.
pub struct BundleStream {
  mut pending : Array[Byte]
  mut cursor : Int
  mut stage : Int
  mut expected_frames : Int
  mut parsed_frames : Int
  mut next_frame_length : Int
  mut manifest : Manifest?
  mut seen : Array[Bool]
  mut received_bytes : Int
  max_input_bytes : Int
  max_object_bytes : Int
  max_encoded_bytes : Int
}

///|
pub fn BundleStream::new(
  max_input_bytes? : Int = 134_217_728,
  max_object_bytes? : Int = 67_108_864,
  max_encoded_bytes? : Int = 16_777_216,
) -> BundleStream raise ErasureError {
  if max_input_bytes < 56 || max_input_bytes > 268_435_456 {
    raise InvalidConfiguration("stream byte budget must fit headers and be <= 256 MiB")
  }
  if max_object_bytes < 0 || max_object_bytes > 268_435_456 {
    raise InvalidConfiguration("stream object budget must be <= 256 MiB")
  }
  if max_encoded_bytes < 2 || max_encoded_bytes > 268_435_456 {
    raise InvalidConfiguration("stream encoded budget must be <= 256 MiB")
  }
  {
    pending: [],
    cursor: 0,
    stage: 0,
    expected_frames: -1,
    parsed_frames: 0,
    next_frame_length: -1,
    manifest: None,
    seen: [],
    received_bytes: 0,
    max_input_bytes,
    max_object_bytes,
    max_encoded_bytes,
  }
}

///|
pub fn BundleStream::manifest(self : BundleStream) -> Manifest? {
  self.manifest
}

///|
pub fn BundleStream::parsed_frame_count(self : BundleStream) -> Int {
  self.parsed_frames
}

///|
pub fn BundleStream::buffered_bytes(self : BundleStream) -> Int {
  self.pending.length() - self.cursor
}

///|
fn BundleStream::consume_prefix(self : BundleStream, length : Int) -> Bytes {
  let prefix = Bytes::from_array(
    self.pending[self.cursor:self.cursor + length].to_owned(),
  )
  self.cursor = self.cursor + length
  prefix
}

///|
/// Compact once per input chunk, rather than copying the remaining bundle
/// after every parsed frame in a chunk containing many frames.
fn BundleStream::compact(self : BundleStream) -> Unit {
  if self.cursor > 0 {
    self.pending = self.pending[self.cursor:self.pending.length()].to_owned()
    self.cursor = 0
  }
}

///|
fn BundleStream::accept_header(self : BundleStream) -> Unit raise ErasureError {
  let header = self.consume_prefix(24)
  if header[0] != b'M' || header[1] != b'E' || header[2] != b'R' ||
    header[3] != b'B' {
    raise InvalidEnvelope("bad streaming bundle magic")
  }
  let version = header[4].to_int()
  if version != 1 {
    raise UnsupportedVersion(version)
  }
  if header[5] != b'\x00' || read_u16(header, 6) != 24 ||
    read_u32(header, 8) != 32U || read_u32(header, 16) != 0U {
    raise InvalidEnvelope("invalid streaming bundle header")
  }
  if crc32c(Bytes::from_array(header[0:20].to_array())) != read_u32(header, 20) {
    raise ChecksumMismatch(-1)
  }
  self.expected_frames = read_bounded_int(header, 12)
  self.stage = 1
}

///|
fn BundleStream::accept_manifest(self : BundleStream) -> Unit raise ErasureError {
  let encoded = self.consume_prefix(32)
  let manifest = Manifest::from_bytes(
    encoded,
    max_object_bytes=self.max_object_bytes,
    max_encoded_bytes=self.max_encoded_bytes,
  )
  let total_slots = manifest.stripe_count() *
    (manifest.data_count() + manifest.parity_count())
  if self.expected_frames != total_slots {
    raise InvalidManifest("stream frame count disagrees with manifest")
  }
  self.seen = Array::make(total_slots, false)
  self.manifest = Some(manifest)
  self.stage = 2
}

///|
fn BundleStream::accept_frame(
  self : BundleStream,
  encoded : Bytes,
) -> ShardEnvelope raise ErasureError {
  let frame = ShardEnvelope::from_bytes(
    encoded,
    max_encoded_bytes=self.max_encoded_bytes,
  )
  let manifest = match self.manifest {
    Some(value) => value
    None => raise InvalidManifest("stream has no manifest")
  }
  if frame.set_id() != manifest.set_id() ||
    frame.data_count() != manifest.data_count() ||
    frame.parity_count() != manifest.parity_count() {
    raise InvalidEnvelope("stream frame identity or codec differs from manifest")
  }
  let stripe_index = frame.stripe_index()
  if stripe_index < 0 || stripe_index >= manifest.stripe_count() {
    raise InvalidIndex(stripe_index)
  }
  if frame.original_length() != manifest.stripe_length(stripe_index) {
    raise InvalidEnvelope("stream frame stripe length differs from manifest")
  }
  let slot = stripe_index * (manifest.data_count() + manifest.parity_count()) +
    frame.shard_index()
  if self.seen[slot] {
    raise DuplicateIndex(frame.shard_index())
  }
  self.seen[slot] = true
  self.parsed_frames = self.parsed_frames + 1
  frame
}

///|
/// Feed any nonempty or empty byte chunk. Return frames completed by it.
/// Discard the stream after an error; earlier returned frames remain valid.
pub fn BundleStream::push(
  self : BundleStream,
  chunk : Bytes,
) -> Array[ShardEnvelope] raise ErasureError {
  if self.stage == 3 && chunk.length() > 0 {
    raise InvalidEnvelope("trailing bytes after complete bundle")
  }
  if chunk.length() > self.max_input_bytes - self.received_bytes {
    raise ResourceLimit("stream input exceeds byte budget")
  }
  self.received_bytes = self.received_bytes + chunk.length()
  for byte in chunk {
    self.pending.push(byte)
  }
  let completed : Array[ShardEnvelope] = []
  let mut working = true
  while working {
    if self.stage == 0 {
      if self.buffered_bytes() >= 24 {
        self.accept_header()
      } else {
        working = false
      }
    } else if self.stage == 1 {
      if self.buffered_bytes() >= 32 {
        self.accept_manifest()
      } else {
        working = false
      }
    } else if self.stage == 2 {
      if self.parsed_frames == self.expected_frames {
        self.stage = 3
        if self.buffered_bytes() != 0 {
          raise InvalidEnvelope("trailing bytes after complete bundle")
        }
        working = false
      } else if self.next_frame_length == -1 {
        if self.buffered_bytes() >= 4 {
          let encoded_length = self.consume_prefix(4)
          let length = read_bounded_int(encoded_length, 0)
          if length < 33 || length > self.max_input_bytes {
            raise InvalidEnvelope("invalid streaming frame length")
          }
          self.next_frame_length = length
        } else {
          working = false
        }
      } else if self.buffered_bytes() >= self.next_frame_length {
        let encoded = self.consume_prefix(self.next_frame_length)
        completed.push(self.accept_frame(encoded))
        self.next_frame_length = -1
      } else {
        working = false
      }
    } else {
      working = false
    }
  }
  self.compact()
  completed
}

///|
/// Confirm that the full bundle ended exactly at a frame boundary.
pub fn BundleStream::finish(self : BundleStream) -> Manifest raise ErasureError {
  if self.stage != 3 || self.buffered_bytes() != 0 {
    raise InvalidEnvelope("truncated streaming bundle")
  }
  match self.manifest {
    Some(value) => value
    None => raise InvalidManifest("stream has no manifest")
  }
}

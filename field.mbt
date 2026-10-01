///|
/// GF(2^8) with irreducible polynomial 0x11d and generator 2.
/// Keeping tables inside a codec avoids mutable global state across backends.
priv struct Field {
  exp : Array[Int]
  log : Array[Int]
}

///|
fn Field::new() -> Field {
  let exp = Array::make(512, 0)
  let log = Array::make(256, 0)
  let mut value = 1
  for i = 0; i < 255; i = i + 1 {
    exp[i] = value
    log[value] = i
    value = value << 1
    if value >= 256 {
      value = value ^ 0x11d
    }
  }
  for i = 255; i < 512; i = i + 1 {
    exp[i] = exp[i - 255]
  }
  { exp, log }
}

///|
fn Field::multiply(self : Field, left : Int, right : Int) -> Int {
  if left == 0 || right == 0 {
    0
  } else {
    self.exp[self.log[left] + self.log[right]]
  }
}

///|
fn Field::inverse(self : Field, value : Int) -> Int raise ErasureError {
  if value == 0 {
    raise SingularMatrix
  }
  self.exp[255 - self.log[value]]
}

///|
fn Field::power(self : Field, value : Int, exponent : Int) -> Int {
  if exponent == 0 {
    return 1
  }
  if value == 0 {
    return 0
  }
  self.exp[self.log[value] * exponent % 255]
}

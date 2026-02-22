# png-matrix plugin — full explanation

A line-by-line walkthrough of the Rust source, plus instructions for compiling
it to WebAssembly and wiring it up in Typst.

---

## Compiling to WASM

### 1. Install Rust

If you don't have Rust yet:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# then restart your shell, or run:
source "$HOME/.cargo/env"
```

### 2. Add the WASM target

Typst plugins must be compiled for `wasm32-unknown-unknown` — a WASM target
with no assumed OS. Typst's runtime provides the allocator, so standard Rust
(`std`) works fine despite the target name:

```bash
rustup target add wasm32-unknown-unknown
```

### 3. Build

```bash
cargo build --release --target wasm32-unknown-unknown
```

The compiled plugin ends up at:

```
target/wasm32-unknown-unknown/release/png_matrix.wasm
```

### 4. (Optional) Shrink the binary

WASM files can be large. `wasm-opt` from the
[binaryen](https://github.com/WebAssembly/binaryen) toolkit can shrink them
significantly:

```bash
# install binaryen (macOS)
brew install binaryen

# install binaryen (Ubuntu/Debian)
apt install binaryen

# optimise
wasm-opt -Oz \
  target/wasm32-unknown-unknown/release/png_matrix.wasm \
  -o png_matrix.wasm
```

Without `wasm-opt`, just copy the file manually:

```bash
cp target/wasm32-unknown-unknown/release/png_matrix.wasm .
```

### 5. Use it in Typst

Place `png_matrix.wasm` in the same directory as your `.typ` file, then:

```typst
#let plugin    = plugin("png_matrix.wasm")
#let img-bytes = read("my_image.png", encoding: none)

#let dims = json(bytes(plugin.dimensions(img-bytes)))
#let gray = json(bytes(plugin.decode_gray(img-bytes)))
#let rgb  = json(bytes(plugin.decode_rgb(img-bytes)))
```

---

## Code walkthrough — `src/lib.rs`

### Imports

```rust
use wasm_minimal_protocol::*;
```

This pulls in the `#[wasm_func]` macro and `initiate_protocol!()`, which handle
the boilerplate of Typst's plugin ABI (how bytes go in and out). Everything else
— `String`, `Vec`, `format!` — comes from Rust's standard library as normal.
Typst's WASM runtime provides a standard allocator, so plain `std` just works.

---

### Protocol initiation

```rust
initiate_protocol!();
```

This macro emits a small piece of WASM that Typst looks for when loading the
plugin, essentially announcing "yes, I speak the right protocol version."
Without it Typst will refuse to load the `.wasm` file. It expands to a hidden
exported function — you don't call it yourself.

---

### The helper function

```rust
fn decode_png(data: &[u8]) -> Result<(u32, u32, Vec<u8>, png::ColorType, png::BitDepth), String> {
```

This is a private helper (no `pub`, not exported to Typst). It takes a byte
slice (`&[u8]`) — a reference to a sequence of bytes, in this case the raw PNG
file contents. It returns a `Result`, which is Rust's way of expressing "this
might fail": the `Ok` variant holds a tuple of
`(width, height, pixel_bytes, color_type, bit_depth)`, and the `Err` variant
holds a `String` error message.

```rust
    let decoder = png::Decoder::new(data);
```

Creates a PNG decoder from the `png` crate, pointed at our byte slice.

```rust
    let mut reader = decoder.read_info().map_err(|e| format!("png error: {e}"))?;
```

`read_info()` parses the PNG header and returns a reader ready to decode frames.
It returns a `Result`, so `.map_err(|e| format!(...))` converts any error into a
human-readable `String`. The `?` at the end is Rust's early-return shorthand:
if it's an `Err`, the whole function immediately returns that error; if it's
`Ok`, we unwrap the value and continue.

```rust
    let mut buf = vec![0u8; reader.output_buffer_size()];
```

Allocates a buffer of zeroed bytes big enough to hold the decoded pixel data.
`output_buffer_size()` tells us exactly how many bytes we'll need.

```rust
    let info = reader.next_frame(&mut buf).map_err(|e| format!("png frame error: {e}"))?;
```

Decodes the first (and usually only) frame of the PNG into `buf`, filling it
with raw pixel bytes. Returns metadata about the frame (width, height, color
type, etc.) which we store in `info`.

```rust
    buf.truncate(info.buffer_size());
```

The buffer we allocated might be slightly larger than the actual frame data, so
we trim it to the exact right size.

```rust
    Ok((info.width, info.height, buf, info.color_type, info.bit_depth))
}
```

Everything succeeded, so wrap the results in `Ok` and return them.

---

### `decode_gray` — the exported grayscale function

```rust
#[wasm_func]
pub fn decode_gray(data: &[u8]) -> Result<Vec<u8>, String> {
```

`#[wasm_func]` is the macro that exports this function to Typst. It rewrites the
function signature into the low-level WASM ABI (raw pointer + length pairs) so
you don't have to. `pub` makes it visible. The return type `Result<Vec<u8>,
String>` means: on success, return bytes (which we'll fill with JSON text); on
failure, return an error string that Typst will surface.

```rust
    let (w, h, buf, color, _depth) = decode_png(data)?;
    let w = w as usize;
    let h = h as usize;
```

Calls our helper and destructures the tuple. `_depth` is prefixed with `_` to
tell Rust "I'm intentionally ignoring this." We cast `w` and `h` from `u32` to
`usize` because we'll use them for array indexing, which requires `usize` in
Rust.

```rust
    let luma: Vec<u8> = match color {
```

`match` is Rust's pattern matching — like a `switch` but exhaustive (the
compiler forces you to handle every case). We branch on the color type to
convert whatever format the PNG uses into a flat vec of grayscale bytes.

```rust
        png::ColorType::Grayscale => buf,
```

Already grayscale — use the buffer as-is.

```rust
        png::ColorType::GrayscaleAlpha => {
            buf.chunks(2).map(|c| c[0]).collect()
        }
```

Grayscale + alpha: pixels are stored as `[gray, alpha]` pairs. `.chunks(2)`
splits the flat buffer into two-element slices, `.map(|c| c[0])` takes just the
gray byte from each, and `.collect()` gathers them into a new `Vec`.

```rust
        png::ColorType::Rgb => {
            buf.chunks(3)
                .map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) as u8)
                .collect()
        }
```

RGB pixels are `[r, g, b]` triples. We convert to luma using the standard
ITU-R BT.601 coefficients — these weights reflect how human eyes perceive
brightness (we're more sensitive to green than red, and least sensitive to
blue). The `as f32` and `as u8` are explicit numeric casts.

```rust
        png::ColorType::Rgba => {
            buf.chunks(4)
                .map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) as u8)
                .collect()
        }
```

Same as RGB but pixels are 4 bytes; we just ignore the alpha channel (index 3).

```rust
        _ => return Err(String::from("unsupported color type")),
```

The `_` wildcard catches anything else (indexed color, etc.). We bail out with
an error.

---

### Building the JSON string

```rust
    let mut json = String::from("[");
    for row in 0..h {
        if row > 0 { json.push(','); }
        json.push('[');
        for col in 0..w {
            if col > 0 { json.push(','); }
            json.push_str(&format!("{}", luma[row * w + col]));
        }
        json.push(']');
    }
    json.push(']');
    Ok(json.into_bytes())
```

We build a JSON array-of-arrays by hand (no JSON library, to keep the WASM
small). `row * w + col` converts 2D coordinates into a flat buffer index —
because even though the image is conceptually a grid, `buf` is a single
contiguous block of bytes in memory, so row 1 starts at index `w`, row 2 at
`2*w`, and so on. `json.into_bytes()` converts the `String` into a `Vec<u8>`
— which is what Typst receives as raw bytes — and we wrap it in `Ok` to signal
success.

---

### `decode_rgb` and `dimensions`

These follow exactly the same patterns as `decode_gray`. The main new thing in
`decode_rgb` is that each pixel becomes a `[u8; 3]` — a fixed-size array of 3
bytes — and we format each one as `[r,g,b]` in the JSON.

`dimensions` is the simplest of the three: it calls `decode_png`, throws away
the pixel buffer, and just formats width and height into a small JSON object.

---

## Caveats

- **16-bit PNGs** are not handled — pixel values will be silently truncated to
  8 bits. Most PNGs you encounter are 8-bit so this rarely matters.
- **Large images** produce large JSON strings. For a 1920×1080 image,
  `decode_gray` returns ~4 MB of JSON. Typst will parse it fine, but if you
  only need a subregion, consider adding a function that accepts crop coordinates.
- **Animated PNGs** — only the first frame is decoded.

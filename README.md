# CAUTION: the rust part has been _entirely_ vibe-coded by claude. I do not know rust at all. No warranty, etc.

The following readme was also written by claude, unprompted. 

See `test/` for examples. 

# png-matrix — Typst WASM plugin

Decode a PNG image into a pixel matrix from within a Typst document.

## Build

```bash
# 1. Install Rust (if you haven't)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. Add the WASM target
rustup target add wasm32-unknown-unknown

# 3. Build
cargo build --release --target wasm32-unknown-unknown

# 4. Copy the .wasm next to your .typ file
cp target/wasm32-unknown-unknown/release/png_matrix.wasm .
```

## Usage in Typst

```typst
#let plugin = plugin("png_matrix.wasm")
#let img-bytes = read("my_image.png", encoding: none)

// Grayscale matrix  →  array of arrays, values 0-255
#let gray = json(bytes(plugin.decode_gray(img-bytes)))

// RGB matrix  →  array of arrays of (r, g, b) triples
#let rgb = json(bytes(plugin.decode_rgb(img-bytes)))

// Dimensions  →  dict with "width" and "height"
#let dims = json(bytes(plugin.dimensions(img-bytes)))
```

## Notes

- Input can be Grayscale, GrayscaleAlpha, RGB, or RGBA PNG.
- `decode_gray` converts color images to luma (0.299R + 0.587G + 0.114B).
- 16-bit PNGs are not currently handled (values will be truncated to 8-bit).
- Large images produce large JSON strings; for very big images consider
  processing only a region, or using this to verify small thumbnails.

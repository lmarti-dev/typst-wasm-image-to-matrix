//! Typst WASM plugin: decode a PNG and return its pixels as a flat JSON array.
//!
//! Exported functions (called from Typst via `plugin(...).FUNC(bytes)`):
//!
//!   decode_gray(png_bytes) -> JSON  [[row0_px0, row0_px1, ...], [row1_px0, ...], ...]
//!   decode_rgb(png_bytes)  -> JSON  [[[r,g,b], ...], ...]
//!   dimensions(png_bytes)  -> JSON  {"width": W, "height": H}

use wasm_minimal_protocol::*;

initiate_protocol!();

// ── helpers ───────────────────────────────────────────────────────────────────

fn decode_png(data: &[u8]) -> Result<(u32, u32, Vec<u8>, png::ColorType, png::BitDepth), String> {
    let decoder = png::Decoder::new(data);
    let mut reader = decoder.read_info().map_err(|e| format!("png error: {e}"))?;
    let mut buf = vec![0u8; reader.output_buffer_size()];
    let info = reader.next_frame(&mut buf).map_err(|e| format!("png frame error: {e}"))?;
    buf.truncate(info.buffer_size());
    Ok((info.width, info.height, buf, info.color_type, info.bit_depth))
}

// In wasm-minimal-protocol 0.1, #[wasm_func] functions must return Vec<u8>.
// Errors are signalled via panic — the protocol catches panics and surfaces
// the message as an error in Typst. We use this small wrapper to bridge our
// Result-returning inner functions to that interface.
fn unwrap_or_panic<T>(r: Result<T, String>) -> T {
    match r {
        Ok(v) => v,
        Err(e) => panic!("{}", e),
    }
}

// ── exported functions ────────────────────────────────────────────────────────

/// Returns a 2-D JSON array of grayscale values (0–255).
/// RGB images are converted to luma via  0.299R + 0.587G + 0.114B.
#[wasm_func]
pub fn decode_gray(data: &[u8]) -> Vec<u8> {
    unwrap_or_panic(decode_gray_inner(data))
}

fn decode_gray_inner(data: &[u8]) -> Result<Vec<u8>, String> {
    let (w, h, buf, color, _depth) = decode_png(data)?;
    let w = w as usize;
    let h = h as usize;

    let luma: Vec<u8> = match color {
        png::ColorType::Grayscale => buf,
        png::ColorType::GrayscaleAlpha => {
            buf.chunks(2).map(|c| c[0]).collect()
        }
        png::ColorType::Rgb => {
            buf.chunks(3)
                .map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) as u8)
                .collect()
        }
        png::ColorType::Rgba => {
            buf.chunks(4)
                .map(|c| (0.299 * c[0] as f32 + 0.587 * c[1] as f32 + 0.114 * c[2] as f32) as u8)
                .collect()
        }
        _ => return Err(String::from("unsupported color type")),
    };

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
}

/// Returns a 2-D JSON array of [r, g, b] triples.
#[wasm_func]
pub fn decode_rgb(data: &[u8]) -> Vec<u8> {
    unwrap_or_panic(decode_rgb_inner(data))
}

fn decode_rgb_inner(data: &[u8]) -> Result<Vec<u8>, String> {
    let (w, h, buf, color, _depth) = decode_png(data)?;
    let w = w as usize;
    let h = h as usize;

    let rgb: Vec<[u8; 3]> = match color {
        png::ColorType::Rgb => buf.chunks(3).map(|c| [c[0], c[1], c[2]]).collect(),
        png::ColorType::Rgba => buf.chunks(4).map(|c| [c[0], c[1], c[2]]).collect(),
        png::ColorType::Grayscale => buf.iter().map(|&v| [v, v, v]).collect(),
        png::ColorType::GrayscaleAlpha => buf.chunks(2).map(|c| [c[0], c[0], c[0]]).collect(),
        _ => return Err(String::from("unsupported color type")),
    };

    let mut json = String::from("[");
    for row in 0..h {
        if row > 0 { json.push(','); }
        json.push('[');
        for col in 0..w {
            if col > 0 { json.push(','); }
            let [r, g, b] = rgb[row * w + col];
            json.push_str(&format!("[{r},{g},{b}]"));
        }
        json.push(']');
    }
    json.push(']');
    Ok(json.into_bytes())
}

/// Returns {"width": W, "height": H}
#[wasm_func]
pub fn dimensions(data: &[u8]) -> Vec<u8> {
    unwrap_or_panic(dimensions_inner(data))
}

fn dimensions_inner(data: &[u8]) -> Result<Vec<u8>, String> {
    let (w, h, _, _, _) = decode_png(data)?;
    Ok(format!("{{\"width\":{w},\"height\":{h}}}").into_bytes())
}

#import "@preview/suiji:0.5.1": gen-rng-f, random-f

#let plugin = plugin("png_matrix.wasm")
#let gradient = ".'`^,:;Il!i><~+_-?][}{1)(|\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"


#let ascii_gray(fpath, sz: 5pt, randomize_rot: false) = {
  let img-bytes = read(fpath, encoding: none)

  let dims = json(
    bytes(plugin.dimensions(img-bytes)),
  )

  let gray = json(
    bytes(plugin.decode_gray(img-bytes)),
  )
  let rng = gen-rng-f(42)
  let angle

  box(width: dims.width * sz, height: dims.height * sz)[
    #for (y, row) in gray.enumerate() {
      for (x, item) in row.enumerate() {
        let ratio = 1 - float(item) / 255.0
        let ind = int(calc.round(float(gradient.len() - 1) * ratio))
        let dx = sz * dims.width * x / row.len()
        let dy = sz * dims.height * y / gray.len()
        if randomize_rot {
          (rng,angle) = random-f(rng)
          place(rotate(angle*360deg,gradient.at(ind)), dx: dx, dy: dy)
        } else {
          place(gradient.at(ind), dx: dx, dy: dy)
        }
      }
    }

  ]
}


#let ascii_rgb(fpath, sz: 5pt) = {
  let img-bytes = read(fpath, encoding: none)
  let cvals = (red, green, blue)

  let dims = json(
    bytes(plugin.dimensions(img-bytes)),
  )
  let rgb = json(
    bytes(plugin.decode_rgb(img-bytes)),
  )
  box(width: dims.width * sz, height: dims.height * sz)[
    #for (y, row) in rgb.enumerate() {
      for (x, item) in row.enumerate() {
        let dx = sz * dims.width * x / row.len()
        let dy = sz * dims.height * y / rgb.len()

        for (ci, clr) in item.enumerate() {
          let ratio = 1 - float(clr) / 255.0
          let ind = int(calc.round(float(gradient.len() - 1) * ratio))

          place(text(gradient.at(ind), fill: cvals.at(ci)), dx: dx, dy: dy)
        }
      }
    }]
}



#let ascii_sym(fpath, sz: 5pt, symbol: sym.floral) = {
  let img-bytes = read(fpath, encoding: none)
  let cvals = (red, green, blue)
  let angvals = (60deg, 90deg, 120deg)

  let dims = json(
    bytes(plugin.dimensions(img-bytes)),
  )
  let rgb = json(
    bytes(plugin.decode_rgb(img-bytes)),
  )
  box(width: dims.width * sz, height: dims.height * sz)[
    #for (y, row) in rgb.enumerate() {
      for (x, item) in row.enumerate() {
        let dx = sz * dims.width * x / row.len()
        let dy = sz * dims.height * y / rgb.len()

        for (ci, clr) in item.enumerate() {
          let ratio = float(clr) / 255.0
          let ind = int(calc.round(float(gradient.len() - 1) * ratio))

          place(text(rotate(angvals.at(ci))[#symbol], fill: cvals.at(ci).opacify(-ratio * 100%)), dx: dx, dy: dy)
        }
      }
    }]
}

#let artct(fpath, fn, factor: 100%) = {
  align(left)[
    #box(stroke: black + 1pt)[
      #scale(x: factor, y: factor)[
        #fn(fpath)]
    ]
  ]
  // pagebreak()
}

#let fpath = "ttsm.png"


#artct(fpath, ascii_gray)
#artct(fpath, ascii_rgb)
#artct(fpath, ascii_sym)





#let plugin = plugin("png_matrix.wasm")
#let gradient=".'`^,:;Il!i><~+_-?][}{1)(|\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"



#let ascii_gray(fpath)={
  let img-bytes = read(fpath, encoding: none)

  let dims = json(
    bytes(plugin.dimensions(img-bytes))
  )

  let gray = json(
    bytes(plugin.decode_gray(img-bytes))
)

for (y,row) in gray.enumerate() {
  for (x,item) in row.enumerate() {
    let ratio = 1-float(item)/255.0
    let ind  = int(calc.round(float(gradient.len()-1) * ratio ))
    let dx = 3pt * dims.width * x/row.len()
    let dy = 3pt * dims.height * y/gray.len()

    place(gradient.at(ind),dx:dx, dy:dy)
  }
}
}


#let ascii_rgb(fpath)={
let img-bytes = read(fpath, encoding: none)
let cvals = (red,green,blue)

let dims = json(
  bytes(plugin.dimensions(img-bytes))
)
let rgb = json(
  bytes(plugin.decode_rgb(img-bytes))
)
for (y,row) in rgb.enumerate() {
  for (x,item) in row.enumerate() {
    let dx = 3pt * dims.width * x/row.len()
    let dy = 3pt * dims.height * y/rgb.len()

    for (ci,clr) in item.enumerate() {
    let ratio = 1-float(clr)/255.0
    let ind  = int(calc.round(float(gradient.len()-1) * ratio ))

    place(text(gradient.at(ind),fill:cvals.at(ci)),dx:dx, dy:dy)}
  }
}
}



#align(left)[
  #scale(x:50%,y:50%)[
  #ascii_gray("tt.png")]
]
#pagebreak()
#align(left)[
  #scale(x:50%,y:50%)[
  #ascii_rgb("tt.png")]
]


import
  std/[math],
  chroma

type
  Colour* = distinct int
  GradientPos* = range[0.0..1.0]
  EasingType* = enum
    easeNone = "None", easeInSine = "Sine in", easeOutSine = "Sine out",
    easeInOutSine = "Sine in out"
  ColourSpace* {.pure.} = enum
    RGB, HSL, HCL
  MultiColourGradientColour* = tuple[colour: Colour; pos: GradientPos]
  MultiColourGradient* = object
    colours*: seq[MultiColourGradientColour]
    easing*: EasingType
    colourSpace*: ColourSpace

func getRGB(colour: Colour): ColorRGB =
  let colour = colour.int
  rgb(uint8(colour shr 16 and 255), uint8(colour shr 8 and 255), uint8(
      colour and 255))

func rgbToColour(c: ColorRGB): Colour =
  # Colors need to be converted to unit32
  # otherwise an 8 bit ´& 0xff´ bitmask will cause red and green to be 0
  # in newer versions of nim.
  let r: uint32 = c.r
  let g: uint32 = c.g
  let b: uint32 = c.b
  return Colour(r shl 16 or g shl 8 or b)

func calculateEase(pos: GradientPos; ease: EasingType): GradientPos =
  case ease
  of easeNone: pos
  of easeInSine: 1 - cos(pos * PI / 2)
  of easeOutSine: sin(pos * PI / 2)
  of easeInOutSine: -0.5 * (cos(pos * PI) - 1)

func getGradientColourAt*(
  colour1, colour2: Colour; pos: GradientPos; ease: EasingType;
  colourSpace: ColourSpace
): Colour =
  let
    colour1 = getRGB(colour1)
    colour2 = getRGB(colour2)
    pos = calculateEase(pos, ease)

  func mix(a, b: uint8): uint8 =
    uint8(a.float * (1.0 - pos.float) + b.float * pos.float)
  func mix(a, b: float): float =
    a * (1.0 - pos.float) + b * pos.float
  func mixHue(a, b: float): float =
    let diff = b - a
    var p: float
    # Decide direction of hue transition
    if diff > 180.0:
      p = a - (360 - diff) * pos
    elif diff < -180.0:
      p = a + (360 + diff) * pos
    else:
      p = a + diff * pos

    if p > 360.0:
      p -= 360.0
    if p < 0.0:
      p += 360.0
    p

  case colourSpace
  of ColourSpace.RGB:
    let colour = rgb(mix(colour1.r, colour2.r), mix(colour1.g, colour2.g), mix(
        colour1.b, colour2.b))
    result = rgbToColour colour
  of ColourSpace.HSL:
    var colour1 = colour1.asHSL
    var colour2 = colour2.asHSL

    # Make hue the same if there isn't much colour
    if colour1.s < 0.1 or colour1.l < 0.2 or colour1.l > 99.8:
      colour1.h = colour2.h
    if colour2.s < 0.2 or colour2.l < 0.2 or colour2.l > 99.8:
      colour2.h = colour1.h

    let colour = hsl(mixHue(colour1.h, colour2.h), mix(colour1.s,
        colour2.s), mix(colour1.l, colour2.l))
    result = rgbToColour colour.asRgb

  of ColourSpace.HCL:
    var colour1 = colour1.asPolarLuv
    var colour2 = colour2.asPolarLuv

    # Make hue the same if there isn't much colour
    if colour1.c < 0.2 or colour1.l < 0.2 or colour1.l > 99.8:
      colour1.h = colour2.h
    if colour2.c < 0.2 or colour2.l < 0.2 or colour2.l > 99.8:
      colour2.h = colour1.h

    let colour = polarLUV(mixHue(colour1.h, colour2.h), mix(colour1.c,
        colour2.c), mix(colour1.l, colour2.l))
    result = rgbToColour colour.asRgb

func getColourAt*(
  gradient: MultiColourGradient; pos: GradientPos
): Colour =
  var
    colour1 = Colour 0
    colour2 = Colour 0
    gradientPos = GradientPos 0.0
  for i in 0..gradient.colours.high:
    let c2 = gradient.colours[i]
    if c2.pos >= pos:
      if i == 0:
        return c2.colour
      let c1 = gradient.colours[i-1]
      colour2 = c2.colour
      colour1 = c1.colour
      gradientPos = (pos - c1.pos) / (c2.pos - c1.pos)
      break
    if i == gradient.colours.high:
      return c2.colour
  return getGradientColourAt(
    colour1, colour2, gradientPos, gradient.easing, gradient.colourSpace
  )

func defaultMultiColourGradient*: MultiColourGradient =
  MultiColourGradient(
    colours: @[
      (Colour 0x2222ff, GradientPos 0), (Colour 0xff2222, GradientPos 1.0)
    ],
    easing: easeNone,
    colourSpace: ColourSpace.RGB
  )

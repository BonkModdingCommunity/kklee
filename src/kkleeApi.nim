when not defined js:
  {.error: "This module only works on the JavaScipt platform".}

import
  std/[strutils, sequtils, dom, math, sugar],
  pkg/[mathexpr]

# Import functions that update or hook into updates of parts of the map editor
# UI

template importUpdateFunction(name: untyped;
    procType: type = proc(): void) =
  let `update name`* {.importc: "window.kklee.$1"inject.}: procType
  var `afterUpdate name`* {.importc: "window.kklee.$1"inject.}: procType

importUpdateFunction(LeftBox)
importUpdateFunction(RightBoxBody, proc(fx: int): void)
# Argument b: if true, rerender shapes
# if false, only update preview position and scale
importUpdateFunction(Renderer, proc(b: bool): void)
importUpdateFunction(Warnings)
importUpdateFunction(UndoButtons)
importUpdateFunction(ModeDropdown)

var afterNewMapObject* {.importc: "window.kklee.$1".}: proc(): void
let saveToUndoHistory* {.importc: "window.kklee.$1".}: proc(): void

# Import getters and setters for IDs of currently selected elements

template importCurrentThing(name: untyped) =
  let `getCurrent name`* {.importc: "window.kklee.$1"inject.}: proc(): int
  let `setCurrent name`* {.importc: "window.kklee.$1"inject.}: proc(i: int)

importCurrentThing(Body)
importCurrentThing(Spawn)
importCurrentThing(CapZone)

proc setColourPickerColour*(colour: int) {.importc: "window.kklee.$1".}
proc dataLimitInfo*: cstring {.importc: "kklee.dataLimitInfo".}
proc panStage*(deltaX, deltaY: int) {.importc: "kklee.stageRenderer.panStage".}
proc scaleStage*(scale: float) {.importc: "kklee.stageRenderer.scaleStage".}

type
  MapPosition* = array[2, float] # X and Y
  MapData* = ref object
    v*: int # Map format version
    m*: MapMetaData
    spawns*: seq[MapSpawn]
    capZones*: seq[MapCapZone]
    physics*: MapPhysics
  MapMetaData* = ref object
    # Name, author, date, mode
    n*, a*, date*, mo*: cstring
    # Original name and author if map is an edit
    rxn*, rxa*: cstring
    # Database ID, bonk version (1 or 2), author's account DBID
    dbid*, dbv*, authid*: int
    # Original map's bonk version and ID
    rxdb*, rxid*: int
    # Is map public
    pub*: bool
    # List of contributors' usernames
    cr*: seq[cstring]

  MapSpawn* = ref object
    # Name
    n*: cstring
    priority*: int
    # FFA, red, blue, green, yellow
    f*, r*, b*, gr*, ye*: bool
    # Position and starting velocity
    x*, y*, xv*, yv*: float
  MapCapZone* = ref object
    # Name
    n*: cstring
    # Type
    ty*: MapCapZoneType
    # Fixture ID
    i*: int
    # Time
    l*: float
  MapCapZoneType* = enum
    cztNormal = 1, cztRed, cztBlue, cztGreen, cztYellow

  MapPhysics* = ref object
    # Player radius = ppm
    ppm*: float
    fixtures*: seq[MapFixture]
    shapes*: seq[MapShape]
    bodies*: seq[MapBody]
    # Array of body IDs, specifies order of bodies
    bro*: seq[int]
    joints*: seq[MapJoint]

  MapBody* = ref object
    # Angle and angular velocity
    a*, av*: float
    # Position, starting velocity
    p*, lv*: MapPosition
    # Fixture IDs of shapes on platform
    fx*: seq[int]
    cf*: MapBodyCf
    fz*: MapBodyFz
    s*: MapSettings
  # Body settings?
  MapSettings* = ref object
    n*: cstring
    # Type: "s" (stationary), "d" (free-moving) or "k" (kinematic)
    # Type is a keyword in Nim
    btype* {.extern: "type".}: cstring
    # Angular drag
    ad*: float
    # Density, friction, linear drag, bounciness
    de*, fric*, ld*, re*: float
    # Collide with groups: A, B, C, D, players
    f_1*, f_2*, f_3*, f_4*, f_p*: bool
    # Collision group
    f_c*: MapBodyCollideGroup
    # Fixed rotation, fric players, anti-tunnel
    fr*, fricp*, bu*: bool
  # Force zone props
  MapBodyFz* = ref object
    # x, y
    x*, y*: float
    # enabled
    on*: bool
    # affect discs, platforms, arrows
    d*, p*, a*: bool
  # Constant force
  MapBodyCf* = ref object
    # x, y, torque
    x*, y*, ct*: float
    # Force direction - true: absolute, false: relative
    w*: bool
  MapBodyCollideGroup* {.pure.} = enum
    A = 1, B, C, D
  MapBodyType* = enum
    btStationary = "s", btDynamic = "d", btKinematic = "k"

  MapFixture* = ref object
    # Name
    n*: cstring
    # Death, no grapple, no physics, fric players, inner grapple
    d*, ng*, np*, fp*, ig*: bool
    # Density, bounciness, friction
    # Set to null for no value
    de*, re*, fr*: float
    # Colour ("fill")
    f*: int
    # Shape ID
    sh*: int

  MapShapeType* = enum
    stypeBx = "bx", stypeCi = "ci", stypePo = "po"
  MapShape* = ref object
    # Shape type
    stype* {.exportc: "type".}: cstring
    # Position
    c*: MapPosition
    # Angle
    a* {.exportc: "a".}: float
    # Shrink, not available for polygons
    sk* {.exportc: "sk".}: bool
    # Rectangle width and height
    bxW* {.exportc: "w".}: float
    bxH* {.exportc: "h".}: float
    # Circle radius
    ciR* {.exportc: "r".}: float
    # Polygon scale and vertices
    poS* {.exportc: "s".}: float
    poV* {.exportc: "v".}: seq[MapPosition]

  MapJoint* = ref object
    # ba: Joint body
    # bb: attached body, -1 if none
    ba*, bb*: int

func shapeType*(s: MapShape): MapShapeType = parseEnum[MapShapeType]($s.stype)

var mapObject* {.importc: "window.kklee.mapObject".}: MapData
var bonkMapObject* {.importc: "window.kklee.bonkMapObject".}: MapData


# Force float64 arrays so that nim handles them correctly.

proc fxShape*(fxo: MapFixture): MapShape =
  let sh: MapShape = mapObject.physics.shapes[fxo.sh]

  {.emit: [sh.c, "= new Float64Array(", sh.c, ");"]}
  if sh.stype == "po":
    {.emit: [sh.poV, "=", sh.poV, ".map(v => new Float64Array(v));"]}
  return sh


proc getBody*(bi: int): MapBody =
  let b: MapBody = mapObject.physics.bodies[bi]

  {.emit: [b.p, "= new Float64Array(", b.p, ");"]}
  {.emit: [b.lv, "= new Float64Array(", b.lv, ");"]}
  return b

proc getFx*(fxId: int): MapFixture = mapObject.physics.fixtures[fxId]

template x*(arr: MapPosition): untyped = arr[0]
template `x=`*(arr: MapPosition; v): untyped = arr[0] = v
template y*(arr: MapPosition): untyped = arr[1]
template `y=`*(arr: MapPosition; v): untyped = arr[1] = v

func rotatePoint*(p: MapPosition; a: float): MapPosition =
  [
    p.x * cos(a) - p.y * sin(a),
    p.x * sin(a) + p.y * cos(a)
  ]

template moph*: untyped = mapObject.physics

# Delete a fixture from the map
proc deleteFx*(fxId: int) =
  let shId = fxId.getFx.sh
  moph.fixtures.delete fxId
  moph.shapes.delete shId
  for b in moph.bodies:
    b.fx.keepItIf it != fxId
    for f in b.fx.mitems:
      if f > fxId: dec f
  for c in mapObject.capZones.mitems:
    if c.i == fxId: c.i = -1
    if c.i > fxId: dec c.i
  for f in moph.fixtures.mitems:
    if f.sh > shId: dec f.sh

proc deleteBody*(bId: int) =
  while bId.getBody.fx.len > 0:
    deleteFx bId.getBody.fx[0]
  moph.bodies.delete bId
  moph.bro.keepItIf it != bId
  for otherBId in moph.bro.mitems:
    if otherBId > bId: dec otherBId
  block:
    var jId = 0
    while jId < moph.joints.len:
      let j = moph.joints[jId]
      if j.ba == bId:
        moph.joints.delete jId
        continue
      if j.bb == bId:
        j.bb = -1
      if j.ba > bId:
        dec j.ba
      if j.bb > bId:
        dec j.bb
      inc jId

var editorPreviewTimeMs* {.importc: "window.kklee.$1".}: float

func copyObject*[T: ref](x: T): T =
  proc structuredClone(_: T): T {.importc: "window.structuredClone".}
  x.structuredClone

let jsNull* {.importc: "null".}: float

proc docElemById*(s: cstring): Element =
  document.getElementById(s)

# Set explanation text at bottom middle of editor
proc setEditorExplanation*(text: string) =
  docElemById("mapeditor_midbox_explain").innerText = text

proc mathExprJsRandom*(_: seq[float]): float {.importc: "window.Math.random".}

type
  MapBackupObject* = ref object

let mapBackups* {.importc: "window.kklee.backups".}: seq[MapBackupObject]
func getBackupLabel*(b: MapBackupObject): cstring
  {.importc: "window.kklee.getBackupLabel".}
proc loadBackup*(b: MapBackupObject) {.importc: "window.kklee.loadBackup".}

proc dispatchInputEvent*(n: Node) {.importc: "window.kklee.dispatchInputEvent".}

proc bonkShowColorPicker*(firstColour: int; fixtureSeq: seq[MapFixture];
  onInput: int -> void; onSave: int -> void
) {.importc: "window.kklee.bonkShowColorPicker".} # onSave can be nil

proc splitConcaveIntoConvex*(v: seq[MapPosition]): seq[seq[MapPosition]]
  {.importc: "window.kklee.splitConcaveIntoConvex".}

proc multiSelectNameChanger*(input: string; thingIndex: int): string =
  let evtor = newEvaluator()
  evtor.addVar("i", thingIndex.float)
  evtor.addFunc("rand", mathExprJsRandom, 0)
  var nameParts = input.split("||")
  if nameParts.len mod 2 == 0:
    raise CatchableError.newException(
      "multiSelectNameChanger nameParts.len is even")
  for i in countup(1, nameParts.high, 2):
    nameParts[i] = evtor.eval(nameParts[i]).formatFloat(precision = -1)
  return nameParts.join("")

proc multiSelectNameChangerCheck*(input: string): string =
  discard multiSelectNameChanger(input, 0)
  input

proc canTransferOwnership*: bool
  {.importc: "window.kklee.canTransferOwnership".}

proc playBonkButtonClickSound* {.importc: "window.kklee.scopedData.bcs".}
proc playBonkButtonHoverSound* {.importc: "window.kklee.scopedData.bhs".}

proc setEnableUpdateChecks*(enable: bool)
  {.importc: "window.kklee.setEnableUpdateChecks".}
func areUpdateChecksEnabled*: bool
  {.importc: "window.kklee.areUpdateChecksEnabled".}

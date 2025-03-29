import
  std/[sugar, strutils, sequtils, algorithm, dom, math, options, strformat],
  pkg/karax/[karax, karaxdsl, vdom, vstyles],
  kkleeApi, bonkElements, platformMultiSelect, colours

var
  selectedFixtures*: seq[MapFixture]
  fixturesBody*: MapBody

proc removeDeletedFixtures =
  var i = 0
  while i < selectedFixtures.len:
    let fx = selectedFixtures[i]
    if fx notin moph.fixtures:
      selectedFixtures.delete i
    else:
      inc i

proc shapeMultiSelectElementBorders* =
  removeDeletedFixtures()
  if getCurrentBody() == -1: return
  let
    shapeElements = document
      .getElementById("mapeditor_rightbox_shapetablecontainer")
      .getElementsByClassName("mapeditor_rightbox_table_shape_headerfield")
      .reversed
    body = getCurrentBody().getBody
  for i, se in shapeElements:
    let prevNode = se.previousSibling
    if not prevNode.isNil and prevNode.class ==
        "kkleeMultiSelectShapeIndexLabel":
      prevNode.remove()

    let selectedId = selectedFixtures.find(body.fx[i].getFx)
    if selectedId == -1:
      se.classList.remove("kkleeMultiSelectShapeTextBox")
    else:
      se.classList.add("kkleeMultiSelectShapeTextBox")

      let indexLabel = document.createElement("span")
      indexLabel.innerText = cstring $selectedId
      indexLabel.class = "kkleeMultiSelectShapeIndexLabel"
      se.parentNode.insertBefore(indexLabel, se)

proc shapeMultiSelectSwitchPlatform* =
  if getCurrentBody() == -1: return
  removeDeletedFixtures()
  shapeMultiSelectElementBorders()
  fixturesBody = getCurrentBody().getBody


proc shapeMultiSelectEdit: VNode = buildHtml tdiv(
    style = "display: flex; flex-flow: column".toCss):

  proc onMouseEnter =
    setEditorExplanation("""
[kklee]
Shift+click shape name fields to select shapes
Variables:
 - x is the current value
 - i is the index in list of selected shapes (the first shape you selected will have i=0, the next one i=1, i=2, etc)
Mathematical expressions, such as x*2+50, will be evaluated
 - n is number of shapes selected
List of supported functions:
https://github.com/BonkModdingCommunity/kklee/blob/master/guide.md#mathematical-expression-evaluator
    """)

  var appliers {.global.}: seq[(int, MapFixture) -> void]
  var resetters {.global.}: seq[() -> void]

  bonkButton "Reset", proc =
    for fn in resetters:
      fn()

  template floatProp(
    name: string; mapFxProp: untyped;
    inpToProp = floatNop;
    propToInp = floatNop;
  ): untyped =
    let
      inpToPropF = inpToProp
      propToInpF = propToInp
    var inp {.global.}: string = "x"

    once:
      appliers.add proc (i: int; fx {.inject.}: MapFixture) =
        mapFxProp = inpToPropF floatPropApplier(
          inp, i, selectedFixtures.len, propToInpF mapFxProp
        )
      resetters.add proc =
        inp = "x"

    buildHtml:
      prop name, floatPropInput(inp), inp != "x"

  template boolProp(name: string; mapFxProp: untyped): untyped =
    var inp {.global.}: boolPropValue
    once:
      appliers.add proc(i: int; fx {.inject.}: MapFixture) =
        case inp
        of tfsFalse: mapFxProp = false
        of tfsTrue: mapFxProp = true
        of tfsSame: discard
      resetters.add proc =
        inp = tfsSame
    buildHtml:
      prop name, tfsCheckbox(inp), inp != tfsSame

  template colourChanger: untyped =
    type InputType = enum
      Unchanged, OneColour, Gradient
    var
      inputType {.global.} = Unchanged
      oneColourInp {.global.}: int = 0
      multiColourGradientInp {.global.} = defaultMultiColourGradient()
    once:
      appliers.add proc(i: int; fx: MapFixture) =
        case inputType
        of Unchanged: return
        of OneColour: fx.f = oneColourInp
        of Gradient:
          fx.f = getColourAt(
            multiColourGradientInp,
            GradientPos(
              if selectedFixtures.high == 0: 1.0
              else: i / selectedFixtures.high
            )
          ).int
      resetters.add proc =
        inputType = Unchanged
        oneColourInp = 0
        multiColourGradientInp = defaultMultiColourGradient()

    let
      dropdown = dropDownPropSelect(inputType, @[
        ("Unchanged", Unchanged), ("One colour", OneColour),
        ("Gradient", Gradient)
      ])
    buildHtml tdiv:
      prop "Colour", dropdown, inputType != Unchanged
      case inputType
      of Unchanged: discard
      of OneColour:
        colourInput(oneColourInp)
      of Gradient:
        gradientProp(multiColourGradientInp)

  template nameChanger: untyped =
    var
      canChange {.global.} = false
      inp {.global.}: string = "Shape ||i||"
    once:
      appliers.add proc(i: int; fx: MapFixture) =
        if canChange:
          fx.n = cstring multiSelectNameChanger(inp, i)
      resetters.add proc =
        canChange = false
        inp = "Shape ||i||"
    buildHtml:
      let field = buildHtml tdiv(style = "display: flex".toCss):
        checkbox(canChange)
        bonkInput(inp, multiSelectNameChangerCheck, nil, s => s)
      prop "Name", field, canChange

  template rotateAndScale: untyped =
    var
      point {.global.} = [0.0, 0.0].MapPosition
      degrees {.global.} = 0.0
      scale {.global.} = 1.0
    once:
      appliers.add proc(i: int; fx: MapFixture) =
        template sh: untyped = fx.fxShape
        var p = sh.c
        p.x -= point.x
        p.y -= point.y
        if degrees != 0.0:
          p = rotatePoint(p, degrees.degToRad)
        sh.a += degrees.degToRad
        p.x *= scale
        p.y *= scale
        p.x += point.x
        p.y += point.y
        sh.c = p
        case sh.shapeType
        of stypeBx:
          sh.bxW *= scale
          sh.bxH *= scale
        of stypeCi:
          sh.ciR *= scale
        of stypePo:
          sh.poS *= scale
      resetters.add proc =
        point = [0.0, 0.0].MapPosition
        degrees = 0.0
        scale = 1.0
    buildHtml tdiv:
      let pointInput = buildHtml tdiv:
        bonkInput(point[0], prsFLimited, nil, niceFormatFloat)
        bonkInput(point[1], prsFLimited, nil, niceFormatFloat)
      prop "Rotate by", bonkInput(degrees, prsFLimited, nil, niceFormatFloat),
        degrees != 0.0
      prop "Scale by", bonkInput(scale, prsFLimited, nil, niceFormatFloat),
        scale != 1.0
      prop "Around point", pointInput, false

  template editCapZone: untyped =
    var
      tfsCheckboxValue {.global.} = tfsSame
      capZoneType {.global.}: Option[MapCapZoneType]
      capZoneTime {.global.}: float = 10.0
      capZoneTimeCanChange {.global.} = false
    once:
      appliers.add proc(i: int; fx: MapFixture) =
        case tfsCheckboxValue
        of tfsSame:
          discard
        of tfsTrue:
          let fxId = moph.fixtures.find fx
          var cz: MapCapZone
          for ocz in mapObject.capZones:
            if ocz.i == fxId:
              cz = ocz
              break

          if cz.isNil and capZoneType.isNone:
            return
          if cz.isNil:
            mapObject.capZones.add MapCapZone(
              n: "Cap Zone", ty: capZoneType.get, l: capZoneTime, i: fxId)
          else:
            if capZoneType.isSome:
              cz.ty = capZoneType.get
            if capZoneTimeCanChange:
              cz.l = capZoneTime
        of tfsFalse:
          let fxId = moph.fixtures.find fx
          var i = 0
          while i < mapObject.capZones.len:
            let cz = mapObject.capZones[i]
            if cz.i == fxId:
              mapObject.capZones.del i
            else:
              inc i
      resetters.add proc =
        tfsCheckboxValue = tfsSame
        capZoneType = none(MapCapZoneType)
        capZoneTime = 10.0
        capZoneTimeCanChange = false
    buildHtml tdiv:
      prop "Capzone", tfsCheckbox(tfsCheckboxValue), tfsCheckboxValue != tfsSame
      if tfsCheckboxValue == tfsTrue:
        let typeDropdown = buildHtml dropDownPropSelect(capZoneType, @[
          ("Normal", cztNormal), ("Red", cztRed), ("Blue", cztBlue),
          ("Green", cztGreen), ("Yellow", cztYellow)
        ])
        prop "Cz. Type", typeDropdown, capZoneType.isSome
        let timeInput = buildHtml tdiv:
          checkbox(capZoneTimeCanChange)
          bonkInput(capZoneTime, prsFLimited, nil, niceFormatFloat)
        prop "Cz. time", timeInput, capZoneTimeCanChange

  nameChanger()
  floatProp("x", fx.fxShape.c.x)
  floatProp("y", fx.fxShape.c.y)
  block:
    let
      d2r = proc(f: float): float = degToRad(f)
      r2d = proc(f: float): float = radToDeg(f)
    floatProp("Angle", fx.fxShape.a, d2r, r2d)
  floatProp("Rect. width", fx.fxShape.bxW)
  floatProp("Rect. height", fx.fxShape.bxH)
  floatProp("Circle radius", fx.fxShape.ciR)
  floatProp("Poly. scale", fx.fxShape.poS)
  floatProp("Density", fx.de)
  floatProp("Bounciness", fx.re)
  floatProp("Friction", fx.fr)

  boolProp("No physics", fx.np)
  boolProp("No grapple", fx.ng)
  boolProp("Inner grapple", fx.ig)
  boolProp("Death", fx.d)
  boolProp("Shrink", fx.fxShape.sk)

  colourChanger()
  rotateAndScale()
  editCapZone()

  bonkButton "Apply", proc =
    removeDeletedFixtures()
    for i, f in selectedFixtures:
      for a in appliers: a(i, f)
    saveToUndoHistory()
    updateRenderer(true)
    updateRightBoxBody(-1)
    updateLeftBox()


proc shapeMultiSelectCopy: VNode = buildHtml tdiv(
    style = "display: flex; flex-flow: column".toCss):
  var
    copyShapes {.global.}: seq[tuple[fx: MapFixture; sh: MapShape;
        cz: Option[MapCapZone]]]
    pasteAmount {.global.} = 1
  bonkButton "Copy shapes", proc =
    removeDeletedFixtures()
    copyShapes = @[]
    for fx in selectedFixtures:
      let fxId = moph.fixtures.find(fx)
      var copiedCz = none MapCapZone
      for cz in mapObject.capZones:
        if cz.i == fxId:
          copiedCz = some cz.copyObject()
          break
      copyShapes.add (
        fx: fx.copyObject(),
        sh: fx.fxShape.copyObject(),
        cz: copiedCz
      )

  prop "Paste amount", bonkInput(pasteAmount, parseInt, nil, i => $i)
  bonkButton "Paste shapes", proc =
    shapeMultiSelectSwitchPlatform()
    block outer:
      for _ in 1..pasteAmount:
        for (fx, sh, cz) in copyShapes.mitems:
          if fixturesBody.fx.len > 1000:
            break outer
          moph.shapes.add sh.copyObject()
          let newFx = fx.copyObject()
          moph.fixtures.add newFx
          newFx.sh = moph.shapes.high
          selectedFixtures.add newFx
          fixturesBody.fx.add moph.fixtures.high
          if cz.isSome:
            let newCz = cz.get.copyObject()
            newCz.i = moph.fixtures.high
            mapObject.capZones.add newCz
    saveToUndoHistory()
    updateRenderer(true)
    updateRightBoxBody(-1)
    updateLeftBox()

proc shapeMultiSelectSelectAll: VNode = buildHtml tdiv(
  style = "font-size: 13px".toCss
):
  tdiv text &"{selectedFixtures.len} shapes selected"
  block:
    let warningColour =
      if selectedFixtures.anyIt (let fxId = moph.fixtures.find(it);
        fxId != -1 and fxId notin fixturesBody.fx):
          "var(--kkleeErrorColour)" else: "transparent"
    tdiv(style = "color: {warningColour}; font-weight: bold".fmt.toCss):
      text &"Shapes from multiple platforms are selected"

  bonkButton "Reverse selection order", proc =
    selectedFixtures.reverse()
    shapeMultiSelectElementBorders()

  type IncludedPlatforms = enum
    IncludeCurrent, IncludeAll, IncludeMultiSelected
  var includedPlatforms {.global.} = IncludeCurrent

  span text "Include shapes from:"
  let includedPlatformsDropdown = dropDownPropSelect(includedPlatforms, @[
    ("Current platform", IncludeCurrent),
    ("All platforms", IncludeAll),
    ("Multiselected platforms", IncludeMultiSelected)
  ])

  discard (includedPlatformsDropdown.style.setAttr("width", "100%"); 0) # >:(
  includedPlatformsDropdown

  proc includedFixtures: seq[MapFixture] =
    case includedPlatforms
    of IncludeAll: moph.fixtures
    of IncludeCurrent: fixturesBody.fx.mapIt it.getFx
    of IncludeMultiSelected:
      selectedBodies.mapIt(it.fx).concat().mapIt(it.getFx)

  bonkButton "Select all", proc =
    shapeMultiSelectSwitchPlatform()
    if includedPlatforms == IncludeAll:
      selectedFixtures = moph.fixtures
    else:
      for fx in includedFixtures():
        if fx notin selectedFixtures:
          selectedFixtures.add fx
    shapeMultiSelectElementBorders()
  bonkButton "Deselect all", proc =
    shapeMultiSelectSwitchPlatform()
    if includedPlatforms == IncludeAll:
      selectedFixtures = @[]
    else:
      for fx in includedFixtures():
        let i = selectedFixtures.find fx
        if i != -1:
          selectedFixtures.delete i
    shapeMultiSelectElementBorders()
  bonkButton "Invert selection", proc =
    shapeMultiSelectSwitchPlatform()
    for fx in includedFixtures():
      let i = selectedFixtures.find fx
      if i != -1:
        selectedFixtures.delete i
      else:
        selectedFixtures.add fx
    shapeMultiSelectElementBorders()
  bonkButton "Select physics shapes", proc =
    shapeMultiSelectSwitchPlatform()
    for fx in includedFixtures():
      if not fx.np and fx notin selectedFixtures:
        selectedFixtures.add fx
    shapeMultiSelectElementBorders()
  bonkButton "Select shapes with capzone", proc =
    shapeMultiSelectSwitchPlatform()
    for cz in mapObject.capZones:
      let fx = cz.i.getFx
      if fx in includedFixtures() and fx notin selectedFixtures:
        selectedFixtures.add fx
    shapeMultiSelectElementBorders()

  tdiv(style = "margin: 5px 0px".toCss):
    var searchString {.global.} = ""
    prop "Start of name", bonkInput(searchString, s => s, nil, s => s)
    bonkButton "Select by name", proc =
      shapeMultiSelectSwitchPlatform()
      for fx in includedFixtures():
        if fx.n.`$`.startsWith(searchString) and fx notin selectedFixtures:
          selectedFixtures.add fx
      shapeMultiSelectElementBorders()

  tdiv(style = "margin: 5px 0px".toCss):
    var
      searchColour {.global.}: int = 0
    prop "Colour", colourInput(searchColour)
    bonkButton "Select by colour", proc =
      for fx in includedFixtures():
        if fx.f == searchColour and fx notin selectedFixtures:
          selectedFixtures.add fx
      shapeMultiSelectElementBorders()

proc shapeMultiSelectDelete: VNode =
  buildHtml bonkButton "Delete shapes", proc =
    for f in selectedFixtures:
      let fxId = moph.fixtures.find f
      if fxId == -1: continue
      deleteFx(fxId)
    saveToUndoHistory()
    selectedFixtures = @[]
    updateRenderer(true)
    updateRightBoxBody(-1)

proc shapeMultiSelectMove: VNode = buildHtml tdiv(style =
  "display: flex; flex-flow: row wrap; justify-content: space-between;".toCss
    ):
  text "Move"
  template fx: untyped = fixturesBody.fx
  proc update =
    updateRightBoxBody(-1)
    updateRenderer(true)
    saveToUndoHistory()
  proc getSelectedFxIds: seq[int] =
    selectedFixtures.mapIt moph.fixtures.find(it)
  bonkButton "Down", proc =
    let selectedFxIds = getSelectedFxIds()
    for i in countup(1, fx.high):
      if fx[i] in selectedFxIds and
          fx[i - 1] notin selectedFxIds:
        swap(fx[i], fx[i - 1])
    update()
  bonkButton "Up", proc =
    let selectedFxIds = getSelectedFxIds()
    for i in countdown(fx.high - 1, 0):
      if fx[i] in selectedFxIds and
          fx[i + 1] notin selectedFxIds:
        swap(fx[i], fx[i + 1])
    update()
  bonkButton "Bottom", proc =
    let selectedFxIds = getSelectedFxIds()
    var moveIndex = 0
    for i in countup(0, fx.high):
      if fx[i] notin selectedFxIds: continue
      inc moveIndex
      for j in countdown(i, moveIndex):
        swap fx[j], fx[j - 1]
    update()
  bonkButton "Top", proc =
    let selectedFxIds = getSelectedFxIds()
    var moveIndex = fx.high
    for i in countdown(fx.high, 0):
      if fx[i] notin selectedFxIds: continue
      dec moveIndex
      for j in countup(i, moveIndex):
        swap fx[j], fx[j + 1]
    update()
  bonkButton "Reverse", proc =
    var selectedFxIds = getSelectedFxIds()
    let fxIdPositions = collect(newSeq):
      for i, fxId in fx:
        let si = selectedFxIds.find fxId
        if si == -1: continue
        selectedFxIds.del si
        i
    for i in 0..fxIdPositions.len div 2 - 1:
      swap fx[fxIdPositions[i]],
           fx[fxIdPositions[fxIdPositions.high - i]]
    update()

proc shapeMultiSelect*: VNode =
  shapeMultiSelectSwitchPlatform()
  buildHtml(tdiv(
      style = "display: flex; flex-flow: column; row-gap: 10px".toCss)):
    shapeMultiSelectSelectAll()
    shapeMultiSelectEdit()
    shapeMultiSelectMove()
    shapeMultiSelectDelete()
    shapeMultiSelectCopy()

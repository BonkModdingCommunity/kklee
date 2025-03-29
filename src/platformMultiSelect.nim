import
  std/[sugar, strutils, algorithm, sequtils, dom, math, options],
  pkg/karax/[karax, karaxdsl, vdom, vstyles],
  kkleeApi, bonkElements

var selectedBodies*: seq[MapBody]

proc removeDeletedBodies =
  var i = 0
  while i < selectedBodies.len:
    let b = selectedBodies[i]
    if b notin moph.bodies:
      selectedBodies.delete i
    else:
      inc i

proc platformMultiSelectElementBorders * =
  removeDeletedBodies()
  let platformsContainer = docElemById("mapeditor_leftbox_platformtable")
  if platformsContainer.isNil: return
  let platformElements = platformsContainer.children[0].children

  for i, bodyElementParent in platformElements:
    let be = bodyElementParent.children[0].Element

    if be.children.len >= 2 and
        be.children[1].class == "kkleeMultiSelectPlatformIndexLabel":
      be.children[1].remove()

    let selectedId = selectedBodies.find(moph.bro[i].getBody)
    if selectedId == -1:
      be.classList.remove("kkleeMultiSelectPlatform")
    else:
      be.classList.add("kkleeMultiSelectPlatform")

      let indexLabel = document.createElement("span")
      indexLabel.innerText = cstring $selectedId
      indexLabel.class = "kkleeMultiSelectPlatformIndexLabel"
      be.appendChild(indexLabel)

proc platformMultiSelectDelete: VNode =
  buildHtml bonkButton "Delete platforms", proc =
    for b in selectedBodies:
      let bId = moph.bodies.find b
      if bId == -1: continue
      deleteBody bId
    saveToUndoHistory()
    selectedBodies = @[]
    updateRenderer(true)
    updateLeftBox()
    setCurrentBody(-1)
    updateRightBoxBody(-1)

proc platformMultiSelectSelectAll: VNode = buildHtml tdiv:
  bonkButton "Select all", proc =
    selectedBodies = collect(newSeq):
      for bId in moph.bro: bId.getBody
    platformMultiSelectElementBorders()
  bonkButton "Deselect all", proc =
    selectedBodies = @[]
    platformMultiSelectElementBorders()
  bonkButton "Invert selection", proc =
    selectedBodies = collect(newSeq):
      for bId in moph.bro:
        let b = bId.getBody
        if b notin selectedBodies:
          b
    platformMultiSelectElementBorders()
  bonkButton "Reverse selection order", proc =
    selectedBodies.reverse()
    platformMultiSelectElementBorders()

  tdiv(style = "margin: 5px 0px".toCss):
    var searchString {.global.} = ""
    prop "Start of name", bonkInput(searchString, s => s, nil, s => s)
    bonkButton "Select by name", proc =
      selectedBodies = collect(newSeq):
        for bId in moph.bro:
          let b = bId.getBody
          if b.s.n.`$`.startsWith(searchString):
            b
      platformMultiSelectElementBorders()

proc platformMultiSelectEdit: VNode = buildHtml tdiv(
    style = "display: flex; flex-flow: column".toCss):

  proc onMouseEnter =
    setEditorExplanation("""
[kklee]
Shift+click platform elements to select platforms
Variables:
 - x is the current value
 - i is the index in list of selected platforms (the first platform you selected will have i=0, the next one i=1, i=2, etc)
Mathematical expressions, such as x*2+50, will be evaluated
 - n is number of platforms selected
List of supported functions:
https://github.com/BonkModdingCommunity/kklee/blob/master/guide.md#mathematical-expression-evaluator
    """)

  var appliers {.global.}: seq[(int, MapBody) -> void]
  var resetters {.global.}: seq[() -> void]

  bonkButton "Reset", proc =
    for fn in resetters:
      fn()

  template floatProp(
    name: string; mapBProp: untyped;
    inpToProp = floatNop;
    propToInp = floatNop;
  ): untyped =
    let
      inpToPropF = inpToProp
      propToInpF = propToInp
    var inp {.global.}: string = "x"

    once:
      appliers.add proc (i: int; b {.inject.}: MapBody) =
        mapBProp = inpToPropF floatPropApplier(
          inp, i, selectedBodies.len, propToInpF mapBProp
        )
      resetters.add proc =
        inp = "x"

    buildHtml:
      prop name, floatPropInput(inp), inp != "x"

  template boolProp(name: string; mapBProp: untyped): untyped =
    var inp {.global.}: boolPropValue
    once:
      appliers.add proc(i: int; b {.inject.}: MapBody) =
        case inp
        of tfsFalse: mapBProp = false
        of tfsTrue: mapBProp = true
        of tfsSame: discard
      resetters.add proc =
        inp = tfsSame
    buildHtml:
      prop name, tfsCheckbox(inp), inp != tfsSame

  template dropDownProp[T](
    name: string;
    mapBProp: untyped;
    options: openArray[tuple[label: string; value: T]]
  ): untyped =
    var
      inp {.global.}: Option[T]
    once:
      appliers.add proc(i: int; b {.inject.}: MapBody) =
        if inp.isSome:
          mapBProp = inp.get
      resetters.add proc =
        inp = default Option[T]
    buildHtml:
      prop name, dropDownPropSelect(inp, @options), inp.isSome


  template nameChanger: untyped =
    var
      canChange {.global.} = false
      inp {.global.}: string = "Platform ||i||"
    once:
      appliers.add proc(i: int; b: MapBody) =
        if canChange:
          b.s.n = cstring multiSelectNameChanger(inp, i)
      resetters.add proc =
        canChange = false
        inp = "Platform ||i||"
    buildHtml:
      let field = buildHtml tdiv(style = "display: flex".toCss):
        checkbox(canChange)
        bonkInput(inp, multiSelectNameChangerCheck, nil, s => s)
      prop "Name", field, canChange

  dropDownProp("Type", b.s.btype, [
    ("Stationary", cstring $btStationary), ("Free moving", cstring $btDynamic),
    ("Kinematic", cstring $btKinematic)
  ])
  nameChanger()
  floatProp("x", b.p.x)
  floatProp("y", b.p.y)
  block:
    let
      d2r = proc(f: float): float = degToRad(f)
      r2d = proc(f: float): float = radToDeg(f)
    floatProp("Angle", b.a, d2r, r2d)
  floatProp("Bounciness", b.s.re)
  floatProp("Density", b.s.de)
  floatProp("Friction", b.s.fric)
  boolProp("Fric players", b.s.fricp)
  boolProp("Anti-tunnel", b.s.bu)
  type cg = MapBodyCollideGroup
  dropDownProp("Col. group", b.s.f_c, [
    ("A", cg.A), ("B", cg.B), ("C", cg.C), ("D", cg.D)
  ])
  boolProp("Col. players", b.s.f_p)
  boolProp("Col. A", b.s.f_1)
  boolProp("Col. B", b.s.f_2)
  boolProp("Col. C", b.s.f_3)
  boolProp("Col. D", b.s.f_4)
  floatProp("Start speed x", b.lv.x)
  floatProp("Start speed y", b.lv.y)
  floatProp("Start spin", b.av)
  floatProp("Linear drag", b.s.ld)
  floatProp("Spin drag", b.s.ad)
  boolProp("Fixed rotation", b.s.fr)
  floatProp("Apply x force", b.cf.x)
  floatProp("Apply y force", b.cf.y)
  dropDownProp("Force dir.", b.cf.w, [
    ("Absolute", true), ("Relative", false)
  ])
  floatProp("Apply torque", b.cf.ct)
  boolProp("Force zone", b.fz.on)
  floatProp("Force zone x", b.fz.x)
  floatProp("Force zone y", b.fz.y)
  boolProp("Push players", b.fz.d)
  boolProp("Push platforms", b.fz.p)
  boolProp("Push arrows", b.fz.a)

  bonkButton "Apply", proc =
    removeDeletedBodies()
    for i, b in selectedBodies:
      for a in appliers: a(i, b)
    saveToUndoHistory()
    updateRenderer(true)
    updateLeftBox()
    updateRightBoxBody(-1)

proc platformMultiSelectMove: VNode = buildHtml tdiv(style =
  "display: flex; flex-flow: row wrap; justify-content: space-between;".toCss
    ):
  text "Move"
  template bro: untyped = moph.bro
  proc update =
    updateLeftBox()
    updateRenderer(true)
    saveToUndoHistory()
  proc getSelectedBIds: seq[int] =
    selectedBodies.mapIt moph.bodies.find(it)
  bonkButton "Down", proc =
    let selectedBIds = getSelectedBIds()
    for i in countdown(bro.high - 1, 0):
      if bro[i] in selectedBIds and
          bro[i + 1] notin selectedBIds:
        swap(bro[i], bro[i + 1])
    update()
  bonkButton "Up", proc =
    let selectedBIds = getSelectedBIds()
    for i in countup(1, bro.high):
      if bro[i] in selectedBIds and
          bro[i - 1] notin selectedBIds:
        swap(bro[i], bro[i - 1])
    update()
  bonkButton "Bottom", proc =
    let selectedBIds = getSelectedBIds()
    var moveIndex = bro.high
    for i in countdown(bro.high, 0):
      if bro[i] notin selectedBIds: continue
      dec moveIndex
      for j in countup(i, moveIndex):
        swap bro[j], bro[j + 1]
    update()
  bonkButton "Top", proc =
    let selectedBIds = getSelectedBIds()
    var moveIndex = 0
    for i in countup(0, bro.high):
      if bro[i] notin selectedBIds: continue
      inc moveIndex
      for j in countdown(i, moveIndex):
        swap bro[j], bro[j - 1]
    update()
  bonkButton "Reverse", proc =
    var selectedBIds = getSelectedBIds()
    let bIdPositions = collect(newSeq):
      for i, bId in bro:
        let si = selectedBIds.find bId
        if si == -1: continue
        selectedBIds.del si
        i
    for i in 0..bIdPositions.len div 2 - 1:
      swap bro[bIdPositions[i]],
           bro[bIdPositions[bIdPositions.high - i]]
    update()

proc platformMultiSelectCopy: VNode = buildHtml tdiv(
    style = "display: flex; flex-flow: column".toCss):
  var
    copyPlats {.global.}: seq[tuple[
      b: MapBody;
      shapes: seq[tuple[fx: MapFixture; sh: MapShape;
        cz: Option[MapCapZone]]];
      joints: seq[tuple[j: MapJoint; b2Id: Option[int]]];
    ]]
    pasteAmount {.global.} = 1
  prop "Paste amount", bonkInput(pasteAmount, parseInt, nil, i => $i)
  bonkButton ("Instant copy&paste (joints will be attached to original " &
    "platforms)"), proc =
    removeDeletedBodies()

    let sblen = selectedBodies.len
    for _ in 1..pasteAmount:
      var sbi = sbLen
      while sbi > 0:
        dec sbi
        let b = selectedBodies[sbi]
        let bId = moph.bodies.find(b)
        let newB = b.copyObject()
        newB.fx = @[]
        moph.bodies.add newB
        moph.bro.insert(moph.bodies.high, 0)
        selectedBodies.add newB

        for fxId in b.fx:
          let
            newFx = fxId.getFx.copyObject()
            newSh = fxId.getFx.fxShape.copyObject()
          moph.shapes.add newSh
          newFx.sh = moph.shapes.high
          moph.fixtures.add newFx
          newB.fx.add moph.fixtures.high

          var czi = 0
          let czlen = mapObject.capZones.len
          while czi < czlen:
            let cz = mapObject.capZones[czi]
            if cz.i != fxId:
              inc czi
              continue
            let newCz = cz.copyObject()
            newCz.i = moph.fixtures.high
            mapObject.capZones.add newCz
            break

          var ji = 0
          var jlen = moph.joints.len
          while ji < jlen:
            let j = moph.joints[ji]
            if j.ba != bId:
              inc ji
              continue
            let newJ = j.copyObject
            newJ.ba = moph.bodies.high
            moph.joints.add newJ
            inc ji

    saveToUndoHistory()
    updateRenderer(true)
    updateLeftBox()
  bonkButton "Copy (joints will be attached to new pasted platforms)", proc =
    removeDeletedBodies()
    copyPlats = @[]
    for b in selectedBodies:
      let
        bId = moph.bodies.find(b)
        copyB = b.copyObject()
        copyShapes = b.fx.mapIt (
          fx: it.getFx.copyObject(),
          sh: it.getFx.fxShape.copyObject(),
          cz: block:
            var r = none MapCapZone
            for cz in mapObject.capZones:
              if cz.i == it:
                r = some cz.copyObject()
                break
            r
        )
        copyJoints = collect(newSeq):
          for j in moph.joints:
            if j.ba != bId:
              continue
            var b2Id = none int
            if j.bb != -1:
              let t = selectedBodies.find j.bb.getBody
              if t != -1:
                b2Id = some t
            (j: j.copyObject(), b2Id: b2Id)
      copyPlats.add (b: copyB, shapes: copyShapes, joints: copyJoints)

  bonkButton "Paste platforms", proc =
    let ogBodiesLen = moph.bodies.len
    var i = 0
    for _ in 1..pasteAmount:
      for cp in copyPlats:
        let newB = cp.b.copyObject()
        newB.fx = @[]
        moph.bodies.add newB
        moph.bro.insert(moph.bodies.high, i)
        selectedBodies.add newB
        for cs in cp.shapes:
          let
            newFx = cs.fx.copyObject()
            newSh = cs.sh.copyObject()
          moph.shapes.add newSh
          newFx.sh = moph.shapes.high
          moph.fixtures.add newFx
          newB.fx.add moph.fixtures.high
          if cs.cz.isSome:
            let newCz = cs.cz.get.copyObject()
            newCz.i = moph.fixtures.high
            mapObject.capZones.add newCz
        for cj in cp.joints:
          let newJ = cj.j.copyObject()
          newJ.ba = moph.bodies.high
          newJ.bb = if cj.b2Id.isNone: -1
            else: cj.b2Id.get + ogBodiesLen
          moph.joints.add newJ
        inc i

    saveToUndoHistory()
    updateRenderer(true)
    updateLeftBox()

proc platformMultiSelect*: VNode = buildHtml(tdiv(
    style = "display: flex; flex-flow: column; row-gap: 10px".toCss)):
  platformMultiSelectSelectAll()
  platformMultiSelectEdit()
  platformMultiSelectMove()
  platformMultiSelectDelete()
  platformMultiSelectCopy()

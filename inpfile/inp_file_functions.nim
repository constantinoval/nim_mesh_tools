import std/memfiles
import strutils
import std/parseutils
import tables
import std/threadpool
import quaternion


type
    InstanceTransform = object
        name: string = ""
        part: string = ""
        displacement: array[3, float] = [0, 0, 0]
        rotation_point: array[3, float] = [0, 0, 0]
        rotation_axis: array[3, float] = [0, 0, 0]
        rotation_angle: float = 0.0
        quaternion: Quaternion
    InstanceTransforms = Table[string, InstanceTransform]
    FENode = object
        n: int = 1
        crds: array[3, float] = [0.0, 0.0, 0.0]
    NodesTable = Table[string, Table[int, FENode]]
    FEElement = object
        n: int = 1
        nodes: array[8, int]
        elementType: string
    ElementsTable = Table[string, Table[int, FEElement]]
    KeyWordBlock = enum
        Instance
        Node
        Element
        Part
        Other
    AbaqusFEModelRef = ref object
        partNodes: ref NodesTable
        partElements: ref ElementsTable
        transforms: ref InstanceTransforms
    AbaqusInstance = object
        name: string
        nodes: Table[int, FENode]
        elements: Table[int, FEElement]
    AbaqusAssembly = Table[string, AbaqusInstance]

var
    instanceTransformChannel:  Channel[seq[string]]
    nodesParserChannel: Channel[tuple[partName: string, nodes: Table[int, FENode]]]
    elementsParserChannel: Channel[tuple[partName: string, elements: Table[int, FEElement]]]


proc init_quaternion(it: var InstanceTransform) =
    it.quaternion = Quaternion(angle: it.rotation_angle, axis: it.rotation_axis)


proc transformFromLines(lines: openArray[string]): InstanceTransform = 
    var
        i: int = 0
        s: string
    s = lines[0]
    i = s.skipUntil({'='}, 0)+1
    i += s.parseUntil(result.name, ',', i)
    i += s.skipUntil({'='}, i)+1
    result.part = s[i..^1]
    if len(lines)>1:
        let s = lines[1]
        i = 0
        for j in 0..2:
            i += s.skipUntil({'0'..'9'}, i)
            i += s.parseFloat(result.displacement[j], i)
    if len(lines)>2:
        let s = lines[2]
        i = 0
        for j in 0..2:
            i += s.skipUntil({'0'..'9'}, i)
            i += s.parseFloat(result.rotation_point[j], i)
        for j in 0..2:
            i += s.skipUntil({'0'..'9'}, i)
            i += s.parseFloat(result.rotation_axis[j], i)
        i += s.skipUntil({'0'..'9'}, i)
        i += s.parseFloat(result.rotation_angle, i)
    result.init_quaternion

proc nodeFromLine(line: string): FENode =
    var
        i: int = 0
        n: int = 1
        x, y, z: float
    i += line.skipWhile({' '}, i)
    i += line.parseInt(n, i)
    i += line.skipWhile({' ', ','}, i)
    i += line.parseFloat(x, i)
    i += line.skipWhile({' ', ','}, i)
    i += line.parseFloat(y, i)
    i += line.skipWhile({' ', ','}, i)
    i += line.parseFloat(z, i)
    return FENode(n: n, crds: [x, y, z])

proc elementFromLine(line: string): FEElement =
    var
        i: int = 0
        n: int = 1
        nodes: array[1..8, int]
    let L: int = line.len
    i += line.skipWhile({' '}, i)
    i += line.parseInt(n, i)
    for j in 1..8:
        i += line.skipWhile({' ', ','}, i)
        i += line.parseInt(nodes[j], i)
        if i>=L:
            break
    return FEElement(n: n, nodes: nodes)


proc transformParser(transformTable: ref Table[string, InstanceTransform]) {.thread.} =
    while true:
        let lines = instanceTransformChannel.recv()
        if len(lines)==0:
            break
        let it = transformFromLines(lines)
        transformTable[it.name] = it

proc nodesParser(nodes: ref NodesTable) {.thread.} =
    while true:
        let (name, tbl) = nodesParserChannel.recv()
        if name=="Stop":
            break
        nodes[name] = tbl

proc parseNodesTable(lines: seq[string]) =
    var nodes = Table[int, FENode]()
    let partName = lines[0]
    for l in lines[1..^1]:
        let nd = nodeFromLine(l)
        nodes[nd.n] = nd
    nodesParserChannel.send((partName, nodes))

proc elementsParser(elements: ref ElementsTable) {.thread.} =
    while true:
        let (name, tbl) = elementsParserChannel.recv()
        if name=="Stop":
            break
        elements[name] = tbl

proc parseElementsTable(lines: seq[string]) =
    var
        elements = Table[int, FEElement]()
        i: int = 0
    let partName = lines[0]
    i += lines[1].skipUntil({'='}, i)
    let elementType = lines[1][i..^1]
    var el: FEElement
    for l in lines[2..^1]:
        el = elementFromLine(l)
        el.elementType = elementType
        elements[el.n] = el
    elementsParserChannel.send((partName, elements))

proc fileParser(filename: string) {.thread.} = 
    var
        mode = KeyWordBlock.Other
        f = memfiles.open(filename)
        instanceData: seq[string]
        nodesData: seq[string]
        elementsData: seq[string]
        currentPart: string = ""
        i: int = 0
    for l in memSlices(f, delim='\n'):
        let c = cast[cstring](l.data)[0]
        if c == '*':
            let s = $l
            if s.startsWith("*Instance, name="):
                instanceData = @[s]
                mode = KeyWordBlock.Instance
                var i: int = 0
                i += s.skipUntil({'='}, i)+1
                i += s.skipUntil({'='}, i)
                currentPart = s[i+1..^1]
                continue
            if s.startsWith("*Part"):
                i += s.skipUntil({'='}, i)
                currentPart = s[i+1..^1]
                continue
            if s=="*Node":
                mode = KeyWordBlock.Node
                nodesData = @[currentPart]
                continue
            if s.startsWith("*Element, "):
                mode = KeyWordBlock.Element
                elementsData = @[currentPart, s]
                continue
            else:
                mode = KeyWordBlock.Other
                if len(instanceData)!=0:
                    instanceTransformChannel.send(instanceData)
                    instanceData = @[]
                if len(nodesData)!=0:
                    spawn parseNodesTable(nodesData)
                    nodesData = @[]
                if len(elementsData)!=0:
                    spawn parseElementsTable(elementsData)
                    elementsData = @[]
        case mode:
        of KeyWordBlock.Instance:
            instanceData.add($l)
        of KeyWordBlock.Node:
            nodesData.add($l)
        of KeyWordBlock.Element:
            elementsData.add($l)
        else:
            discard    
    sync()
    instanceTransformChannel.send(@[])
    var
        tmp_n = Table[int, FENode]()
        tmp_el = Table[int, FEElement]()
    nodesParserChannel.send(("Stop", tmp_n))
    elementsParserChannel.send(("Stop", tmp_el))


proc fromFile(abaModel: AbaqusFEModelRef, fname: string) = 
    var
        fileReadThread: Thread[string]
        transformParserThread: Thread[ref Table[string, InstanceTransform]]
        nodesParserThread: Thread[ref NodesTable]
        elementsParserThread: Thread[ref ElementsTable]
        transforms: ref Table[string, InstanceTransform]
        nodes: ref NodesTable
        elements: ref ElementsTable
    new(transforms)
    new(nodes)
    new(elements)
    instanceTransformChannel.open
    nodesParserChannel.open
    elementsParserChannel.open
    transformParserThread.createThread(transformParser, transforms)
    nodesParserThread.createThread(nodesParser, nodes)
    elementsParserThread.createThread(elementsParser, elements)
    fileReadThread.createThread(fileParser, fname)
    nodesParserThread.joinThread
    elementsParserThread.joinThread
    fileReadThread.joinThread
    transformParserThread.joinThread
    nodesParserChannel.close
    elementsParserChannel.close
    instanceTransformChannel.close
    abaModel.partNodes = nodes
    abaModel.partElements = elements
    abaModel.transforms = transforms

proc info*(abaModel: AbaqusFEModelRef) = 
    var total_nodes: int
    var total_elements: int
    for k in abaModel[].partNodes.keys:
        let n = abaModel[].partNodes[k].len
        let ne = abaModel[].partElements[k].len
        total_nodes.inc(n)
        total_elements.inc(ne)
        echo k, " узлов : ", n, ", элементов: ", ne
    echo "Всего узлов: ", total_nodes
    echo "Всего элементов: ", total_elements


proc transformPoint(it: InstanceTransform, point: array[3, float]): array[3, float] =
    result = point
    for i in 0..2:
        if it.displacement[i]!=0:
            result[i] += it.displacement[i]
    if it.rotation_angle != 0.0:
        let crds = it.quaternion.rotatePoint([result[0]-it.rotation_point[0],
                                             result[1]-it.rotation_point[1],
                                             result[2]-it.rotation_point[2]])
        for i in 0..2:
            result[i] = crds[i] + it.rotation_point[i]

proc instanceFromPart(instanceName: string, am: AbaqusFEModelRef): AbaqusInstance =
    if  not am[].transforms[].haskey(instanceName):
        echo "Имя ", instanceName, " не найдено в модели"
        return
    let it = am[].transforms[instanceName]
    let part = it.part
    result.name = it.name
    result.elements = am[].partElements[part]
    for nd in am[].partNodes[part].values:
        let an = FENode(n: nd.n, crds: it.transformPoint(nd.crds))
        result.nodes[an.n] = an
    return result


proc assemblyFromAbaqusModel(am: AbaqusFEModelRef): AbaqusAssembly =
    const PARALLEL = true
    when PARALLEL:
        var instances: seq[FlowVar[AbaqusInstance]]
        for inst_name in am[].transforms.keys:
            let inst = spawn instanceFromPart(inst_name, am)
            instances.add(inst)
        for i in instances:
            let ii = ^i
            result[ii.name] = ii
    else:
        for inst_name in am[].transforms.keys:
            let inst = instanceFromPart(inst_name, am)
            result[inst_name] = inst
    return result

proc assemblyFromFile*(filename: string): AbaqusAssembly =
    var abaModel = new(AbaqusFEModelRef)
    abaModel.fromFile(filename)
    return assemblyFromAbaqusModel(abaModel)

proc `$`*(aa: AbaqusInstance): string =
    return "Instance " & aa.name & " узлов: " & $aa.nodes.len & " элементов " & $aa.elements.len

proc `$`*(aa: AbaqusAssembly): string =
    result = "Информация о сборке:\n"
    var total_nodes: int
    var total_elements: int
    for k in aa.keys:
        let n = aa[k].nodes.len
        let ne = aa[k].elements.len
        total_nodes.inc(n)
        total_elements.inc(ne)
        result = result & k & " узлов : " & $n & ", элементов: " & $ne & "\n"
    result = result & "Всего узлов: " & $total_nodes & "\n"
    result = result & "Всего элементов: " & $total_elements & "\n"
    return result

if isMainModule:
    # var it = InstanceTransform(
    #     displacement: [1, 0, 0],
    #     rotation_point: [0, 0, 0],
    #     rotation_axis: [0, 1, 0],
    #     rotation_angle: 90
    #     )
    # it.init_quaternion
    # echo it.transformPoint([1.0, 0, 0])
    var
        assembly: AbaqusAssembly
    assembly = assemblyFromFile("./yap.inp")
    echo assembly
    # abaModel.info
    # echo abaModel[].transforms[]
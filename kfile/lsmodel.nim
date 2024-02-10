import std/tables
import fenode
import feelement
export tables
import std/[os, memfiles, sugar, times, threadpool]
import utils

type
    LSmodel* = object ## LSmodel object represents the FE model from lsdyna k-file
        nodes*: OrderedTable[int, FEnode]
        solids*: OrderedTable[int, FEelement]
        solidsortho*: OrderedTable[int, FEelement]
        shells*: OrderedTable[int, FEelement]
        TOL*:float = 1e-6
        bbox*: tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    KeywordBlock = enum
        Node
        Solid
        Shell
        SolidOrtho
        Undefined

var nodesChannel, shellsChannel, solidsChannel, solidsOrthoChannel:  Channel[string]

proc readFile(filename: string) {.thread.} =
    # echo "File reader started..."
    var
        mode = KeywordBlock.Undefined
        f = memfiles.open(filename)

    for l in memSlices(f, delim='\n'):
        let c = cast[cstring](l.data)[0]
        if c == '$':
            continue
        if  c == '*':
            case $l:
            of "*NODE":
                mode = KeywordBlock.Node
            of "*ELEMENT_SOLID":
                mode = KeywordBlock.Solid
            of "*ELEMENT_SHELL":
                mode = KeywordBlock.Shell
            of "*ELEMENT_SOLID_ORTHO":
                mode = KeywordBlock.SolidOrtho
            else:
                mode = KeywordBlock.Undefined
            continue
        case mode:
        of KeywordBlock.Node:
            nodesChannel.send($l) 
        of KeywordBlock.Solid:
            solidsChannel.send($l)
        of KeywordBlock.SolidOrtho:
            solidsOrthoChannel.send($l)
        of KeywordBlock.Shell:
            shellsChannel.send($l)
        else:
            discard
    f.close()
    nodesChannel.send("")
    solidsChannel.send("")
    shellsChannel.send("")
    solidsOrthoChannel.send("")
    # echo "All lines been proceded..."


proc parseNodes(nodesTable: ref OrderedTable[int, FEnode]) {.thread.} =
    # var count: int
    # echo "Nodes parser started..."
    while true:
        let m = nodesChannel.recv()
        if m == "":
            break
        let nd = fenode.fromStringFast(m)
        nodesTable[][nd.n] = nd
            # inc(count)
    # echo "Parsed ", count, " nodes..."

proc parseSolids(solidsTable: ref OrderedTable[int, FEelement]) {.thread.} =
    # var count: int
    # echo "Solids parser started..."
    while true:
        let m = solidsChannel.recv()
        if m == "":
            break
        let el = feelement.fromStringFast(m, etype=Etype.Solid)
        solidsTable[][el.n] = el
            # inc(count)
    # echo "Parsed ", count, " solids..."

proc parseShells(shellsTable: ref OrderedTable[int, FEelement]) {.thread.} =
    # var count: int
    # echo "Shells parser started..."
    while true:
        let m = shellsChannel.recv()
        if m == "":
            break
        let el = feelement.fromStringFast(m, etype=Etype.Shell)
        shellsTable[][el.n] = el
            # inc(count)
    # echo "Parsed ", count, " shells..."

proc parseSolidsOrtho(solidsOrthoTable: ref OrderedTable[int, FEelement]) {.thread.} =
    # var count = 0
    # echo "Ortho solids parser started..."
    var
        idx = 0
        threelines: array[3, string]
    while true:
        let m = solidsOrthoChannel.recv()
        if idx<=2:
            threelines[idx] = m
            inc(idx)
        if idx==3:
            let el = feelement.fromStringFastOrtho(threelines)
            # inc(count)
            solidsOrthoTable[el.n] = el
            idx = 0
        if m == "":
            break
    # echo "Parsed ", count, " ortho solids..."

proc readMesh*(ls: var LSModel, meshPath: string) =
    if fileExists(meshPath):
        let tm = cpuTime()
        nodesChannel.open
        shellsChannel.open
        solidsChannel.open
        solidsOrthoChannel.open
        var
            fileReadThread: Thread[string]
            nodesParseThread: Thread[ref OrderedTable[int, FEnode]]
            solidsParseThread: Thread[ref OrderedTable[int, FEelement]]
            solidsOrthoParseThread: Thread[ref OrderedTable[int, FEelement]]
            shellsParseThread: Thread[ref OrderedTable[int, FEelement]]
            nodesTable: ref OrderedTable[int, FEnode]
            solidsTable: ref OrderedTable[int, FEelement]
            shellsTable: ref OrderedTable[int, FEelement]
            solidsOrthoTable: ref OrderedTable[int, FEelement]
        new(nodesTable)
        new(solidsTable)
        new(solidsOrthoTable)
        new(shellsTable)
        echo "Чтение сетки из файла " & meshPath
        nodesParseThread.createThread(parseNodes, nodesTable)
        solidsParseThread.createThread(parseSolids, solidsTable)
        solidsOrthoParseThread.createThread(parseSolidsOrtho, solidsOrthoTable)
        shellsParseThread.createThread(parseShells, shellsTable)
        fileReadThread.createThread(readFile, meshPath) 
        nodesParseThread.joinThread()
        fileReadThread.joinThread()
        joinThreads(solidsParseThread, solidsOrthoParseThread, shellsParseThread)
        echo "Модель прочитана за " & $(cpuTime()-tm) & " сек..."
        ls.nodes = nodesTable[]
        ls.solids = solidsTable[]
        ls.solidsortho = solidsOrthoTable[]
        ls.shells = shellsTable[]
        nodesChannel.close
        solidsChannel.close
        shellsChannel.close
        solidsOrthoChannel.close

    
proc determinateBbox*(model: var LSmodel) = 
    var
        minX: float = 1e9
        maxX: float = -1e9
        minY: float = 1e9
        maxY: float = -1e9
        minZ: float = 1e9
        maxZ: float = -1e9
    for nd in model.nodes.values():
        minX = min(minX, nd.x)
        maxX = max(maxX, nd.x)
        minY = min(minY, nd.y)
        maxY = max(maxY, nd.y)
        minZ = min(minZ, nd.z)
        maxZ = max(maxZ, nd.z)
    model.bbox = (minX, minY, minZ, maxX, maxY, maxZ)

func planeXmin*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.x-model.bbox.minx)<model.TOL:
            result.add(n)

proc modelInfo(model: LSmodel): string =
    result &= "\nИнформация о модели:\nЧисло узлов: " & $(model.nodes.len) & "\n"
    result &= "Число оболочечных элементов: " & $(model.shells.len) & "\n"
    result &= "Число объемных элементов: " & $(model.solids.len) & "\n"
    result &= "Число объемных элементов с материальными осями: " & $(model.solidsortho.len) & "\n"

func elementVolume*(model: LSmodel, elNum: int): float =
    ##[
        Определение объема элемента, заданного номером
    ]##
    result = -1
    if elNum in model.solids:
        let el = model.solids[elNum]
        var idxs: seq[array[1..4, int]]
        case el.nodes_count:
            of 4:
                idxs = @[[1, 2, 3, 4]]
            of 6:
                idxs = @[
                    [1, 2, 4, 5],
                    [5, 2, 4, 3],
                    [5, 4, 3, 6]
                    ]
            of 8:
                idxs = @[
                    [1, 5, 6, 8],
                    [3, 7, 6, 8],
                    [1, 3, 4, 8],
                    [1, 3, 6, 8],
                    [1, 2, 3, 6]
                    ]
            else:
                discard
        result = 0
        for row in idxs:
            let nodes: seq[FEnode] = collect:
                for i in row:
                    model.nodes[el.nds[i]]
            result += volume4nodes(nodes)

proc calculateElementVolumes*(model: var LSmodel) =
    ##[
        Расчет объемов элементов модели
    ]##
    for el in model.solids.keys():
        model.solids[el].volume = model.elementVolume(el)

proc calculateElementVolumesParallel*(model: LSmodel, num_threads: int = 4) =
    ##[
        Расчет объемов элементов модели в параллельном режиме
    ]##
    let element_refs = collect:
        for el in model.solids.values:
            el.addr
    proc procOnePeace(start_addr: pointer, length: int, model: ptr LSmodel) =
        var data = cast[ptr UncheckedArray[ptr FEelement]](start_addr)
        for i in 0 ..< length:
            let el = data[][i]
            el.volume = model[].elementVolume(el.n)
    let peaces = splitSeq(element_refs.len, num_threads)
    for p in peaces:
        spawn procOnePeace(element_refs[p.start].addr, p.length, model.addr)
    sync()


when isMainModule:
    var ls = LSmodel()
    # ls.solids[1] = FEelement(nds: [1, 2, 3, 4, 5, 6, 7, 8], nodes_count: 8, n: 1)
    # ls.nodes[1] = FEnode(x: 0, y: 0, z: 0, n: 1)
    # ls.nodes[2] = FEnode(x: 1, y: 0, z: 0, n: 2)
    # ls.nodes[3] = FEnode(x: 1, y: 1, z: 0, n: 3)
    # ls.nodes[4] = FEnode(x: 0, y: 1, z: 0, n: 4)
    # ls.nodes[5] = FEnode(x: 0, y: 0, z: 1, n: 5)
    # ls.nodes[6] = FEnode(x: 1, y: 0, z: 1, n: 6)
    # ls.nodes[7] = FEnode(x: 1, y: 1, z: 1, n: 7)
    # ls.nodes[8] = FEnode(x: 0, y: 1, z: 1, n: 8)
    # var tm = getTime()
    # tm = getTime()
    ls.readMesh("./small_model.k")
    echo "Расчет объемов элементов"
    ls.calculateElementVolumesParallel()
    for i in 1..10:
        echo ls.solids[i].volume
    # echo getTime()-tm
    # tm = getTime()
    ls.calculateElementVolumes()
    echo "-----"
    for i in 1..10:
        echo ls.solids[i].volume
    # echo getTime()-tm

    echo "Готово..."

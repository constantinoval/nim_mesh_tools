import std/tables
import fenode
import feelement
export tables
import std/[os, memfiles, sugar, times, threadpool]
import utils
import std/streams
import std/intsets


type
    LSmodel* = ref object ## LSmodel object represents the FE model from lsdyna k-file
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
        # let tm = cpuTime()
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
        # echo "Чтение сетки из файла " & meshPath
        nodesParseThread.createThread(parseNodes, nodesTable)
        solidsParseThread.createThread(parseSolids, solidsTable)
        solidsOrthoParseThread.createThread(parseSolidsOrtho, solidsOrthoTable)
        shellsParseThread.createThread(parseShells, shellsTable)
        fileReadThread.createThread(readFile, meshPath) 
        nodesParseThread.joinThread()
        fileReadThread.joinThread()
        joinThreads(solidsParseThread, solidsOrthoParseThread, shellsParseThread)
        # echo "Модель прочитана за " & $(cpuTime()-tm) & " сек..."
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
        var idxs: seq[array[1..4, uint8]]
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

proc save*(self: LSmodel, file_path: string) = 
    let f = newFileStream(file_path, fmWrite)
    if not isNil(f):
        f.writeLine("*KEYWORD")
        if self.nodes.len != 0:
            f.writeLine("*NODE")
            for n in self.nodes.values:
                f.writeLine(n.formattedLine)
        if self.solids.len != 0:
            f.writeLine("*ELEMENT_SOLID")
            for e in self.solids.values:
                f.writeLine(e.formattedLine)
        if self.solids_ortho.len != 0:
            f.writeLine("*ELEMENT_SOLID_ORTHO")
            for e in self.solids.values:
                f.writeLine(e.formattedLine)
        f.writeLine("*END")
        f.close()

proc translate*(model: var LSmodel, dx: float = 0, dy: float = 0, dz: float = 0) =
    for nd in model.nodes.mvalues:
        nd.x += dx
        nd.y += dy
        nd.z += dz

proc reflect*(model: var LSmodel, norm: int = 0, tol: float = 1e-6) =
    #[
        norm == 0 - reflect about YZ plane,
        norm == 1 - reflect about XZ plane,
        norm == 2 - reflect about XY plane
    ]#
    # echo "Reflecting model..."
    if not norm in [0, 1, 2]:
        return
    var nshift: int = -1
    var eshift: int = -1
    for num in model.nodes.keys:
        nshift = max(num, nshift)
    for num in model.solids.keys:
        eshift = max(num, eshift)
    let old_nodes = collect:
        for num in model.nodes.keys:
            num
    for num in old_nodes:
        var node = model.nodes[num]
        var crds = [node.x, node.y, node.z]
        if abs(crds[norm])<tol:
            continue
        crds[norm] = -crds[norm]
        let new_node = FEnode(
            n: node.n+nshift,
            x: crds[0],
            y: crds[1],
            z: crds[2]
            )
        model.nodes[new_node.n] = new_node
    let old_elements = collect:
        for num in model.solids.keys:
            num
    for num in old_elements:
        let el = model.solids[num]
        var nodes = model.solids[num].nds
        for i, v in nodes.pairs:
            let n = model.nodes[v]
            let crd: float = case norm:
                of 0: n.x
                of 1: n.y
                of 2: n.z
                else: 0
            if abs(crd)>tol:
                nodes[i] += nshift
        let new_nodes: array[1..8, int] = case el.nodes_count:
            of 4: [nodes[3], nodes[2], nodes[1], nodes[4], 0, 0, 0, 0]
            of 6: [nodes[4], nodes[3], nodes[2], nodes[1], nodes[6], nodes[5], 0, 0]
            of 8: [nodes[4], nodes[3], nodes[2], nodes[1], nodes[8], nodes[7], nodes[6], nodes[5]]
            else: [0, 0, 0, 0, 0, 0, 0, 0]
        let new_element = FEelement(
            n: el.n+eshift,
            nodes_count: el.nodes_count,
            part: el.part,
            nds: new_nodes,
            volume: el.volume,
        )
        model.solids[num+eshift] = new_element
    # echo "done..."

proc renumber_solids*(model: LSmodel) =
    var i = 0
    let new_solids = collect(OrderedTable):
        for s in model.solids.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.solids = new_solids

proc renumber_solidsortho*(model: LSmodel) =
    var i = 0
    let new_solidsortho = collect(OrderedTable):
        for s in model.solidsortho.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.solidsortho = new_solidsortho

proc renumber_shells*(model: LSmodel) =
    var i = 0
    let new_shells = collect(OrderedTable):
        for s in model.shells.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.shells = new_shells

proc renumber_nodes*(model: LSmodel) =
    var i = 0 
    let old_nodes_numbers = collect(newTable):
        for n in model.nodes.keys:
            i += 1
            {n: i}
    i = 0
    let new_nodes = collect(OrderedTable):
        for n in model.nodes.mvalues:
            i += 1
            n.n = i
            {i: n}
    model.nodes = new_nodes
    for s in model.solids.mvalues:
        for i in 1..s.nodes_count:
            s.nds[i] = old_nodes_numbers[s.nds[i]]
    for s in model.solidsortho.mvalues:
        for i in 1..s.nodes_count:
            s.nds[i] = old_nodes_numbers[s.nds[i]]
    for s in model.shells.mvalues:
        for i in 1..s.nodes_count:
            s.nds[i] = old_nodes_numbers[s.nds[i]]

proc delete_unreferenced_nodes*(model: LSmodel): int {.discardable.} = 
    var all_attached_nodes: IntSet
    for s in model.solids.values:
        all_attached_nodes.incl(s.nodes.toIntSet)
    for s in model.solidsortho.values:
        all_attached_nodes.incl(s.nodes.toIntSet)
    for s in model.shells.values:
        all_attached_nodes.incl(s.nodes.toIntSet)
    let nodes_to_delete = collect:
        for n in model.nodes.keys:
            if not all_attached_nodes.contains(n):
                n
    for n in nodes_to_delete:
        model.nodes.del(n)
    return nodes_to_delete.len


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
    echo "Reading..."
    ls.readMesh("./big_model.k")
    echo "Расчет объемов элементов"
    ls.calculateElementVolumesParallel()
    for i in 1..10:
        echo ls.solids[i].volume
    echo "Removing unreferenced nodes..."
    echo "unref nodes count: ", ls.delete_unreferenced_nodes()
    # # echo getTime()-tm
    # # tm = getTime()
    # ls.calculateElementVolumes()
    # echo "-----"
    # for i in 1..10:
    #     echo ls.solids[i].volume
    # # echo getTime()-tm
    # echo "Готово..."
    echo "Renumbering solids..."
    ls.renumber_solids()
    echo "Renumbering nodes..."
    ls.renumber_nodes()
    echo ls.solids[1]
    echo "Reflecting..."
    ls.reflect(norm=0)
    echo "Writting..."
    ls.save("1.k")
    echo "Done..."

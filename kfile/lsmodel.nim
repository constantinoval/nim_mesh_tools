import std/tables
import fenode
import feelement
import point
import quaternion
export tables
import std/[os, memfiles, sugar, times, threadpool]
import utils
import std/streams
import std/intsets
import std/monotimes


type
    Bbox* = tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    LSmodel* = ref object ## LSmodel object represents the FE model from lsdyna k-file
        nodes*: OrderedTable[int, FEnode]
        solids*: OrderedTable[int, FEelement]
        solidsortho*: OrderedTable[int, FEelement]
        shells*: OrderedTable[int, FEelement]
        TOL*:float = 1e-6
        bbox*: Bbox
    KeywordBlock = enum
        Node
        Solid
        Shell
        SolidOrtho
        Undefined

var nodesChannel, shellsChannel, solidsChannel, solidsOrthoChannel:  Channel[string]
nodesChannel.open
shellsChannel.open
solidsChannel.open
solidsOrthoChannel.open

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

proc readMesh*(ls: var LSModel, meshPath: string): bool {.discardable.} =
    if fileExists(meshPath):
        # let tm = cpuTime()
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
        # nodesChannel.close
        # solidsChannel.close
        # shellsChannel.close
        # solidsOrthoChannel.close
        result = true

    
proc determinateBbox*(model: var LSmodel) = 
    var
        minX: float = float.high
        maxX: float = float.low
        minY: float = float.high
        maxY: float = float.low
        minZ: float = float.high
        maxZ: float = float.low
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

func planeXmax*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.x-model.bbox.maxx)<model.TOL:
            result.add(n)

func planeYmin*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.y-model.bbox.miny)<model.TOL:
            result.add(n)

func planeYmax*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.y-model.bbox.maxy)<model.TOL:
            result.add(n)

func planeZmin*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.z-model.bbox.minz)<model.TOL:
            result.add(n)

func planeZmax*(model: LSmodel): seq[int] =
    for n, nd in model.nodes.pairs():
        if abs(nd.z-model.bbox.maxz)<model.TOL:
            result.add(n)

proc modelInfo*(model: LSmodel): string =
    result &= "\nИнформация о модели:\nЧисло узлов: " & $(model.nodes.len) & "\n"
    result &= "Число оболочечных элементов: " & $(model.shells.len) & "\n"
    result &= "Число объемных элементов: " & $(model.solids.len) & "\n"
    result &= "Число объемных элементов с материальными осями: " & $(model.solidsortho.len) & "\n"

func elementVolume*(model: LSmodel, elNum: int): float =
    ##[
        Определение объема элемента, заданного номером
    ]##
    result = -1
    var el: FEelement
    if elNum in model.solids:
        el = model.solids[elNum]
    if elNum in model.solidsortho:
        el = model.solidsortho[elNum]
    if not el.isNil:
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
    for el in model.solidsortho.keys():
        model.solidsortho[el].volume = model.elementVolume(el)

proc calculateElementVolumesParallel*(model: LSmodel, num_threads: int = 4) =
    ##[
        Расчет объемов элементов модели в параллельном режиме
    ]##
    var element_refs = newSeqOfCap[ptr FEelement](model.solids.len+model.solidsortho.len)
    for el in model.solids.values:
        element_refs.add(el.addr)
    for el in model.solidsortho.values:
        element_refs.add(el.addr)
    proc procOnePeace(start_addr: pointer, length: int, model: ptr LSmodel) =
        var data = cast[ptr UncheckedArray[ptr FEelement]](start_addr)
        for i in 0 ..< length:
            let el = data[][i]
            el.volume = model[].elementVolume(el.n)
    let peaces = splitSeq(element_refs.len, num_threads)
    for p in peaces:
        spawn procOnePeace(element_refs[p.start].addr, p.length, model.addr)
    sync()

proc save1*(self: LSmodel, file_path: string) = 
    ##[
        save model to file file_path
        example: model.save("1.k")
    ]##
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

func format_nodes_refs(nds: ptr seq[ptr FEnode], start, stop: int): string =
    for i in start..stop:
        result &= nds[i][].formattedLine & "\n"

func format_solids_refs(solids: ptr seq[ptr FEelement], start, stop: int): string =
    for i in start..stop:
        result &= solids[i][].formattedLine & "\n"

proc save*(self: LSmodel, file_path: string, num_threads: int = 1) = 
    ##[
        save model to file file_path
        example: model.save("1.k")
    ]##
    proc nodes_lines(model: LSmodel, num_threads: int = 1): string =
        if model.nodes.len==0:
            return ""
        if num_threads==1:
            for n in model.nodes.values:
                result &= n.formattedLine & "\n"
        else:
            let node_refs = collect:
                for n in model.nodes.values:
                    addr n
            let peaces = splitSeq(node_refs.len, num_threads)
            var results: seq[FlowVar[string]]
            for p in peaces:
                let r = spawn format_nodes_refs(addr node_refs, p.start, p.start+p.length-1)
                results.add(r)
            for r in results:
                result &= ^r
        result.setLen(result.len-1)
        return result

    proc solids_lines(model: LSmodel, num_threads: int = 1): string =
        if model.solids.len==0:
            return ""
        # var result = newStringOfCap(81*model.nodes.len)
        if num_threads==1:
            for e in model.solids.values:
                result &= e.formattedLine & "\n"
        else:
            let solids_refs = collect:
                for s in model.solids.values:
                    addr s
            let peaces = splitSeq(solids_refs.len, num_threads)
            var results: seq[FlowVar[string]]
            for p in peaces:
                let r = spawn format_solids_refs(addr solids_refs, p.start, p.start+p.length-1)
                results.add(r)
            for r in results:
                result &= ^r
        result.setLen(result.len-1)
        return result

    proc solidsortho_lines(model: LSmodel): string =
        if model.solidsortho.len==0:
            return ""
        # var result = newStringOfCap(81*model.nodes.len)
        for e in model.solidsortho.values:
            result &= e.formattedLine & "\n"
        result.setLen(result.len-1)
        return result

    proc shells_lines(model: LSmodel): string =
        if model.shells.len==0:
            return ""
        # var result = newStringOfCap(81*model.nodes.len)
        for e in model.shells.values:
            result &= e.formattedLine & "\n"
        result.setLen(result.len-1)
        return result

    let f = newFileStream(file_path, fmWrite)
    if not isNil(f):
        let s_nodes = spawn nodes_lines(self, num_threads=num_threads)
        let s_solids = spawn solids_lines(self, num_threads=num_threads)
        let s_solidsortho = spawn solidsortho_lines(self)
        let s_shells = spawn shells_lines(self)
        f.writeLine("*KEYWORD")
        if self.nodes.len != 0:
            f.writeLine("*NODE")
            f.writeLine(^s_nodes)
        if self.solids.len != 0:
            f.writeLine("*ELEMENT_SOLID")
            f.writeLine(^s_solids)
        if self.solidsortho.len != 0:
            f.writeLine("*ELEMENT_SOLID_ORTHO")
            f.writeLine(^s_solidsortho)    
        if self.shells.len != 0:
            f.writeLine("*ELEMENT_SHELL")
            f.writeLine(^s_shells)    
        f.writeLine("*END")
        f.close()


proc translate*(model: var LSmodel, dx: float = 0, dy: float = 0, dz: float = 0) =
    ##[
        translate model by dx, dy, dz
        example: model.translate(dx=10)
    ]##
    for nd in model.nodes.mvalues:
        nd.x += dx
        nd.y += dy
        nd.z += dz

proc rotate*(model: var LSmodel, axis: Point, angle: float) = 
    ##[
        rotate model by angle obout axis(deg)
        example: model.rotate(axis=Point(x: 0, y: 0, z: 0), angle=90)
    ]##
    let q = Quaternion(angle: angle, axis: axis)
    for nd in model.nodes.mvalues:
        q.rotateNode(nd)


proc reflect*(model: var LSmodel, norm: int = 0) =
    ##[
        norm == 0 - reflect about YZ plane,
        norm == 1 - reflect about XZ plane,
        norm == 2 - reflect about XY plane
    ]##
    # echo "Reflecting model..."
    let tol = model.TOL
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
            if v==0:
                break
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

proc renumber_solids*(model: LSmodel, start: int = 1) =
    ##[
        renumber solids 1..solids_count
    ]##
    var i = start - 1
    let new_solids = collect(OrderedTable):
        for s in model.solids.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.solids = new_solids

proc renumber_solidsortho*(model: LSmodel, start: int = 1) =
    ##[
        renumber solidsortho 1..solidsortho_count
    ]##
    var i = start - 1
    let new_solidsortho = collect(OrderedTable):
        for s in model.solidsortho.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.solidsortho = new_solidsortho

proc renumber_shells*(model: LSmodel, start: int = 1) =
    ##[
        renumber shells 1..shells_count
    ]##
    var i = start - 1
    let new_shells = collect(OrderedTable):
        for s in model.shells.mvalues:
            i += 1
            s.n = i
            {i: s}
    model.shells = new_shells

proc renumber_elements*(model: LSmodel, start: int = 1) =
    model.renumber_shells(start = start)
    model.renumber_solids(start = start + model.shells.len)
    model.renumber_solidsortho(start = start + model.shells.len + model.solids.len)

proc renumber_nodes*(model: LSmodel, start: int = 1) =
    ##[
        renumber nodes 1..nodes_count
    ]##
    var i = start - 1
    let old_nodes_numbers = collect(newTable):
        for n in model.nodes.keys:
            i += 1
            {n: i}
    i = start - 1
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
    ##[
        delete from nodes all nodes which are not connected to any element
    ]##
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

proc nearest_node*(model: LSmodel, node_number: int, node_group: ptr IntSet): int =
    ##[
        Find nearest to node_number node from set of node numbers: node_group
    ]##
    if node_number notin model.nodes:
        echo node_number, " not in model..."
        return -1
    let n0 = model.nodes[node_number]
    var dist: float = float.high
    for n in node_group[]:
        if n in model.nodes:
            let d = model.nodes[n].dist2(n0)
            if d<dist:
                result = n
                dist = d
    return result

func parts_numbers*(model: LSmodel): IntSet =
    for e in model.shells.values:
        result.incl(e.part)
    for e in model.solids.values:
        result.incl(e.part)
    for e in model.solidsortho.values:
        result.incl(e.part)

func parts_volumes*(model: LSmodel): Table[int, float] = 
    for e in model.solids.values:
        if e.part notin result:
            result[e.part] = 0
        result[e.part] += e.volume
    for e in model.solidsortho.values:
        if e.part notin result:
            result[e.part] = 0
        result[e.part] += e.volume

func elements_volumes*(model: LSmodel): Table[int, float] =
    for e in model.solids.values:
        result[e.n] = e.volume
    for e in model.solidsortho.values:
        result[e.n] = e.volume

when isMainModule:
    var ls = LSmodel()
    ls.readMesh("big_mesh.k")
    echo ls.modelInfo()
    var t0 = getMonoTime()
    ls.save("1.k", num_threads=1)
    echo "Parallel: ", getMonoTime()-t0
    # echo ls.modelInfo()
    t0 = getMonoTime()
    ls.save1("2.k")
    echo "Serial:   ", getMonoTime()-t0
    # echo ls.modelInfo()
    # ls.calculateElementVolumesParallel()
    # echo ls.parts_volumes
    # m.translate(dx=10.0)

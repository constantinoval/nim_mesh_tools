import ../kfile/lsmodel
import ../kfile/fenode
import std/[tables, sugar, intsets, sequtils, threadpool]
import nimpy
import std/monotimes

const isparallel = false

type
    Bbox* = tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    Mesh* = ref object of PyNimObjectExperimental
        model: LSmodel = LSmodel()
    Mesh_bc_data = tuple[fixed: int, dx, dy, dz: float, pairs: Table[string, seq[seq[array[2, int]]]]]

proc set_tol*(self: Mesh, tol: float = 1e-6) {.exportpy.} =
    self.model.TOL = tol

proc read*(self: Mesh, file_path: string): bool {.exportpy discardable.} =
    ##[
        Чтение сетки из файла
    ]##
    when isparallel:
        return self.model.readMesh(file_path)
    else:
        return self.model.readMeshSerial(file_path)


func nodescount*(self: Mesh): int {.exportpy.} =
    return self.model.nodes.len

func solidscount*(self: Mesh): int {.exportpy.} =
    return self.model.solids.len

func solidsorthocount*(self: Mesh): int {.exportpy.} =
    return self.model.solidsortho.len

func shellscount*(self: Mesh): int {.exportpy.} =
    return self.model.shells.len

proc save*(self: Mesh, file_path: string, num_threads: int = 2) {.exportpy.} =
    ##[
        Сохранение сетки в файл
    ]##
    when isMainModule:
        self.model.save(file_path, num_threads)
    else:
        self.model.saveSerial(file_path)

proc delete_unreferenced_nodes*(self: Mesh): int {.exportpy discardable.} =
    return self.model.delete_unreferenced_nodes()

proc renumber_nodes*(self: Mesh, start: int = 1) {.exportpy.} =
    self.model.renumber_nodes(start)

proc renumber_shells*(self: Mesh, start: int = 1) {.exportpy.} =
    self.model.renumber_shells(start)

proc renumber_solids*(self: Mesh, start: int = 1) {.exportpy.} =
    self.model.renumber_solids(start)

proc renumber_solidsortho*(self: Mesh, start: int = 1) {.exportpy.} =
    self.model.renumber_solidsortho(start)

proc renumber_elements*(self: Mesh, start: int = 1) {.exportpy.} =
    self.model.renumber_elements(start)

proc determinate_bbox*(self: Mesh) {.exportpy.} =
    self.model.determinateBbox()

proc calculate_element_volumes*(self: Mesh, num_threads: int = 0) {.exportpy.} =
    if num_threads<=1 or not isparallel:
        self.model.calculateElementVolumesSerial()
    else:
        self.model.calculateElementVolumesParallel(num_threads=num_threads)

proc bbox*(self: Mesh): Bbox {.exportpy.} =
    ##[
        Границы сеточной модели: tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    ]##
    # if (self.model.bbox.maxx - self.model.bbox.minx)<self.model.TOL:
    return self.model.bbox

proc reflect*(self: Mesh, norm: int) {.exportpy.} =
    ##[
        Отражение модели:
            norm == 0 - относительно плоскости YZ,
            norm == 1 - относительно плоскости XZ,
            norm == 2 - относительно плоскости XY
    ]##
    self.model.reflect(norm=norm)

proc translate*(self: Mesh, dx: float=0, dy: float=0, dz: float=0) {.exportpy.} =
    ##[
        Смещение модели на dx, dy, dz
    ]##
    self.model.translate(dx=dx, dy=dy, dz=dz)

##[
proc pairs_for_periodic_bc_old(self: Mesh): Mesh_bc_data =
    ##[
        Поиск пар узлов для периодических граничных условий
    ]##
    proc find_pairs(model: LSmodel, nodes_set1: IntSet, nodes_set2: IntSet): seq[array[2, int]] =
        var set2 = nodes_set2
        for n1 in nodes_set1:
            let n2 = model.nearest_node(n1, addr set2)
            result.add([n1, n2])
            set2.excl(n2)
            if set2.len == 0:
                break
    var
        # PLANES
        # X normal
        p_ABFE = self.model.planeXmin().toIntSet
        p_DCGH = self.model.planeXmax().toIntSet

        # Y-normal
        p_ADHE = self.model.planeYmin().toIntSet
        p_BCGF = self.model.planeYmax().toIntSet

        # Z-normal
        p_ABCD = self.model.planeZmin().toIntSet
        p_HGFE  = self.model.planeZmax().toIntSet

        # LINES
        # X-parallel
        l_AD = p_ADHE * p_ABCD
        l_BC = p_BCGF * p_ABCD
        l_EH = p_ADHE * p_HGFE
        l_FG = p_BCGF * p_HGFE

        # Y-parallel
        l_AB = p_ABCD * p_ABFE
        l_DC = p_ABCD * p_DCGH
        l_EF = p_HGFE * p_ABFE
        l_HG = p_HGFE * p_DCGH

        # Z-parallel
        l_AE = p_ABFE * p_ADHE
        l_BF = p_ABFE * p_BCGF
        l_DH = p_DCGH * p_ADHE
        l_CG = p_DCGH * p_BCGF

        # POINTS
        A = l_AB * l_AD
        B = l_AB * l_BC
        C = l_DC * l_BC
        D = l_AD * l_DC
        E = l_EH * l_EF
        F = l_EF * l_FG
        G = l_HG * l_CG
        H = l_EH * l_HG
    # removing boundaries    
    p_ABFE = p_ABFE - l_AB - l_EF - l_AE - l_BF
    p_DCGH = p_DCGH - l_DC - l_HG - l_DH - l_CG
    p_ADHE = p_ADHE - l_AD - l_EH - l_AE - l_DH
    p_BCGF = p_BCGF - l_BC - l_FG - l_CG - l_BF
    p_ABCD = p_ABCD - l_DC - l_AB - l_AD - l_BC
    p_HGFE = p_HGFE - l_EF - l_HG - l_EH - l_FG
    l_AD = l_AD - A - D
    l_BC = l_BC - B - C
    l_EH = l_EH - E - H
    l_FG = l_FG - F - G
    l_AB = l_AB - A - B
    l_DC = l_DC - D - C
    l_EF = l_EF - E - F
    l_HG = l_HG - H - G
    l_AE = l_AE - A - E
    l_BF = l_BF - B - F
    l_DH = l_DH - D - H
    l_CG = l_CG - C - G

    result.fixed = A.toSeq()[0]
    result.dx = self.model.bbox.maxx-self.model.bbox.minx
    result.dy = self.model.bbox.maxy-self.model.bbox.miny
    result.dz = self.model.bbox.maxz-self.model.bbox.minz
    let planex = spawn find_pairs(self.model, p_ABFE, p_DCGH)
    let planey = spawn find_pairs(self.model, p_ADHE, p_BCGF)
    let planez = spawn find_pairs(self.model, p_ABCD, p_HGFE)
    let l1x = spawn find_pairs(self.model, l_AD, l_FG)
    let l2x = spawn find_pairs(self.model, l_EH, l_BC)
    let l1y = spawn find_pairs(self.model, l_AB, l_HG)
    let l2y = spawn find_pairs(self.model, l_EF, l_DC)
    let l1z = spawn find_pairs(self.model, l_AE, l_CG)
    let l2z = spawn find_pairs(self.model, l_BF, l_DH)
    result.pairs["planex"] = @[^planex]
    result.pairs["planey"] = @[^planey]
    result.pairs["planez"] = @[^planez]
    result.pairs["linesx"] = @[^l1x, ^l2x]
    result.pairs["linesy"] = @[^l1y, ^l2y]
    result.pairs["linesz"] = @[^l1z, ^l2z]
    result.pairs["points"] = @[
        @[[A.toSeq[0], G.toSeq[0]]],
        @[[B.toSeq[0], H.toSeq[0]]],
        @[[D.toSeq[0], F.toSeq[0]]],
        @[[E.toSeq[0], C.toSeq[0]]],
    ]
]##

proc pairs_for_periodic_bc_parallel(self: Mesh): Mesh_bc_data =
    ##[
        Поиск пар узлов для периодических граничных условий
    ]##
    proc find_pairs_in_plain(
            model: LSmodel,
            nodes_set1: IntSet,
            nodes_set2: IntSet,
            plane: array[0..1, int],
            rounded: int = 6
        ): seq[array[2, int]] =
        var ns1 = collect:
            for n in nodes_set1:
                model.nodes[n]
        var ns2 = collect:
            for n in nodes_set2:
                model.nodes[n]
        ns1.sort2d(rounded, plane)
        ns2.sort2d(rounded, plane)
        let n = min(ns1.len, ns2.len)
        for i in 0..<n:
            result.add([ns1[i].n, ns2[i].n])
    
    proc find_pairs_in_line(
            model: LSmodel,
            nodes_set1: IntSet,
            nodes_set2: IntSet,
            line: int,
            rounded: int = 6
        ): seq[array[2, int]] =
        var ns1 = collect:
            for n in nodes_set1:
                model.nodes[n]
        var ns2 = collect:
            for n in nodes_set2:
                model.nodes[n]
        ns1.sort1d(rounded, line)
        ns2.sort1d(rounded, line)
        let n = min(ns1.len, ns2.len)
        for i in 0..<n:
            result.add([ns1[i].n, ns2[i].n])

    var
        # PLANES
        # X normal
        p_ABFE = self.model.planeXmin().toIntSet
        p_DCGH = self.model.planeXmax().toIntSet

        # Y-normal
        p_ADHE = self.model.planeYmin().toIntSet
        p_BCGF = self.model.planeYmax().toIntSet

        # Z-normal
        p_ABCD = self.model.planeZmin().toIntSet
        p_HGFE  = self.model.planeZmax().toIntSet

        # LINES
        # X-parallel
        l_AD = p_ADHE * p_ABCD
        l_BC = p_BCGF * p_ABCD
        l_EH = p_ADHE * p_HGFE
        l_FG = p_BCGF * p_HGFE

        # Y-parallel
        l_AB = p_ABCD * p_ABFE
        l_DC = p_ABCD * p_DCGH
        l_EF = p_HGFE * p_ABFE
        l_HG = p_HGFE * p_DCGH

        # Z-parallel
        l_AE = p_ABFE * p_ADHE
        l_BF = p_ABFE * p_BCGF
        l_DH = p_DCGH * p_ADHE
        l_CG = p_DCGH * p_BCGF

        # POINTS
        A = l_AB * l_AD
        B = l_AB * l_BC
        C = l_DC * l_BC
        D = l_AD * l_DC
        E = l_EH * l_EF
        F = l_EF * l_FG
        G = l_HG * l_CG
        H = l_EH * l_HG
    # removing boundaries    
    p_ABFE = p_ABFE - l_AB - l_EF - l_AE - l_BF
    p_DCGH = p_DCGH - l_DC - l_HG - l_DH - l_CG
    p_ADHE = p_ADHE - l_AD - l_EH - l_AE - l_DH
    p_BCGF = p_BCGF - l_BC - l_FG - l_CG - l_BF
    p_ABCD = p_ABCD - l_DC - l_AB - l_AD - l_BC
    p_HGFE = p_HGFE - l_EF - l_HG - l_EH - l_FG
    l_AD = l_AD - A - D
    l_BC = l_BC - B - C
    l_EH = l_EH - E - H
    l_FG = l_FG - F - G
    l_AB = l_AB - A - B
    l_DC = l_DC - D - C
    l_EF = l_EF - E - F
    l_HG = l_HG - H - G
    l_AE = l_AE - A - E
    l_BF = l_BF - B - F
    l_DH = l_DH - D - H
    l_CG = l_CG - C - G

    result.fixed = A.toSeq()[0]
    result.dx = self.model.bbox.maxx-self.model.bbox.minx
    result.dy = self.model.bbox.maxy-self.model.bbox.miny
    result.dz = self.model.bbox.maxz-self.model.bbox.minz
    let planex = spawn find_pairs_in_plain(self.model, p_ABFE, p_DCGH, plane=[1, 2])
    let planey = spawn find_pairs_in_plain(self.model, p_ADHE, p_BCGF, plane=[0, 2])
    let planez = spawn find_pairs_in_plain(self.model, p_ABCD, p_HGFE, plane=[0, 1])
    let l1x = spawn find_pairs_in_line(self.model, l_AD, l_FG, line=0)
    let l2x = spawn find_pairs_in_line(self.model, l_EH, l_BC, line=0)
    let l1y = spawn find_pairs_in_line(self.model, l_AB, l_HG, line=1)
    let l2y = spawn find_pairs_in_line(self.model, l_EF, l_DC, line=1)
    let l1z = spawn find_pairs_in_line(self.model, l_AE, l_CG, line=2)
    let l2z = spawn find_pairs_in_line(self.model, l_BF, l_DH, line=2)
    result.pairs["planex"] = @[^planex]
    result.pairs["planey"] = @[^planey]
    result.pairs["planez"] = @[^planez]
    result.pairs["linesx"] = @[^l1x, ^l2x]
    result.pairs["linesy"] = @[^l1y, ^l2y]
    result.pairs["linesz"] = @[^l1z, ^l2z]
    result.pairs["points"] = @[
        @[[A.toSeq[0], G.toSeq[0]]],
        @[[B.toSeq[0], H.toSeq[0]]],
        @[[D.toSeq[0], F.toSeq[0]]],
        @[[E.toSeq[0], C.toSeq[0]]],
    ]

proc pairs_for_periodic_bc_serial(self: Mesh): Mesh_bc_data =
    ##[
        Поиск пар узлов для периодических граничных условий
    ]##
    proc find_pairs_in_plain(
            model: LSmodel,
            nodes_set1: IntSet,
            nodes_set2: IntSet,
            plane: array[0..1, int],
            rounded: int = 6
        ): seq[array[2, int]] =
        var ns1 = collect:
            for n in nodes_set1:
                model.nodes[n]
        var ns2 = collect:
            for n in nodes_set2:
                model.nodes[n]
        ns1.sort2d(rounded, plane)
        ns2.sort2d(rounded, plane)
        let n = min(ns1.len, ns2.len)
        for i in 0..<n:
            result.add([ns1[i].n, ns2[i].n])
    
    proc find_pairs_in_line(
            model: LSmodel,
            nodes_set1: IntSet,
            nodes_set2: IntSet,
            line: int,
            rounded: int = 6
        ): seq[array[2, int]] =
        var ns1 = collect:
            for n in nodes_set1:
                model.nodes[n]
        var ns2 = collect:
            for n in nodes_set2:
                model.nodes[n]
        ns1.sort1d(rounded, line)
        ns2.sort1d(rounded, line)
        let n = min(ns1.len, ns2.len)
        for i in 0..<n:
            result.add([ns1[i].n, ns2[i].n])

    var
        # PLANES
        # X normal
        p_ABFE = self.model.planeXmin().toIntSet
        p_DCGH = self.model.planeXmax().toIntSet

        # Y-normal
        p_ADHE = self.model.planeYmin().toIntSet
        p_BCGF = self.model.planeYmax().toIntSet

        # Z-normal
        p_ABCD = self.model.planeZmin().toIntSet
        p_HGFE  = self.model.planeZmax().toIntSet

        # LINES
        # X-parallel
        l_AD = p_ADHE * p_ABCD
        l_BC = p_BCGF * p_ABCD
        l_EH = p_ADHE * p_HGFE
        l_FG = p_BCGF * p_HGFE

        # Y-parallel
        l_AB = p_ABCD * p_ABFE
        l_DC = p_ABCD * p_DCGH
        l_EF = p_HGFE * p_ABFE
        l_HG = p_HGFE * p_DCGH

        # Z-parallel
        l_AE = p_ABFE * p_ADHE
        l_BF = p_ABFE * p_BCGF
        l_DH = p_DCGH * p_ADHE
        l_CG = p_DCGH * p_BCGF

        # POINTS
        A = l_AB * l_AD
        B = l_AB * l_BC
        C = l_DC * l_BC
        D = l_AD * l_DC
        E = l_EH * l_EF
        F = l_EF * l_FG
        G = l_HG * l_CG
        H = l_EH * l_HG
    # removing boundaries    
    p_ABFE = p_ABFE - l_AB - l_EF - l_AE - l_BF
    p_DCGH = p_DCGH - l_DC - l_HG - l_DH - l_CG
    p_ADHE = p_ADHE - l_AD - l_EH - l_AE - l_DH
    p_BCGF = p_BCGF - l_BC - l_FG - l_CG - l_BF
    p_ABCD = p_ABCD - l_DC - l_AB - l_AD - l_BC
    p_HGFE = p_HGFE - l_EF - l_HG - l_EH - l_FG
    l_AD = l_AD - A - D
    l_BC = l_BC - B - C
    l_EH = l_EH - E - H
    l_FG = l_FG - F - G
    l_AB = l_AB - A - B
    l_DC = l_DC - D - C
    l_EF = l_EF - E - F
    l_HG = l_HG - H - G
    l_AE = l_AE - A - E
    l_BF = l_BF - B - F
    l_DH = l_DH - D - H
    l_CG = l_CG - C - G
    result.fixed = A.toSeq()[0]
    result.dx = self.model.bbox.maxx-self.model.bbox.minx
    result.dy = self.model.bbox.maxy-self.model.bbox.miny
    result.dz = self.model.bbox.maxz-self.model.bbox.minz
    let planex = find_pairs_in_plain(self.model, p_ABFE, p_DCGH, plane=[1, 2])
    let planey = find_pairs_in_plain(self.model, p_ADHE, p_BCGF, plane=[0, 2])
    let planez = find_pairs_in_plain(self.model, p_ABCD, p_HGFE, plane=[0, 1])
    let l1x = find_pairs_in_line(self.model, l_AD, l_FG, line=0)
    let l2x = find_pairs_in_line(self.model, l_EH, l_BC, line=0)
    let l1y = find_pairs_in_line(self.model, l_AB, l_HG, line=1)
    let l2y = find_pairs_in_line(self.model, l_EF, l_DC, line=1)
    let l1z = find_pairs_in_line(self.model, l_AE, l_CG, line=2)
    let l2z = find_pairs_in_line(self.model, l_BF, l_DH, line=2)
    result.pairs["planex"] = @[planex]
    result.pairs["planey"] = @[planey]
    result.pairs["planez"] = @[planez]
    result.pairs["linesx"] = @[l1x, l2x]
    result.pairs["linesy"] = @[l1y, l2y]
    result.pairs["linesz"] = @[l1z, l2z]
    result.pairs["points"] = @[
        @[[A.toSeq[0], G.toSeq[0]]],
        @[[B.toSeq[0], H.toSeq[0]]],
        @[[D.toSeq[0], F.toSeq[0]]],
        @[[E.toSeq[0], C.toSeq[0]]],
    ]

proc pairs_for_periodic_bc*(self: Mesh): Mesh_bc_data  {.exportpy.} =
    when isparallel:
        return pairs_for_periodic_bc_parallel(self)
    else:
        return pairs_for_periodic_bc_serial(self)

proc info*(self: Mesh): string {.exportpy.} =
    return self.model.modelInfo

func elements_volumes*(self: Mesh): Table[int, float] {.exportpy.} = 
    return self.model.elements_volumes()

func parts_volumes*(self: Mesh): Table[int, float] {.exportpy.} =
    return self.model.parts_volumes()

func parts_numbers*(self: Mesh): seq[int] {.exportpy.} =
    return self.model.parts_numbers().toSeq

when isMainModule:
    # var m = new(Mesh)
    # m.read("yap.k")
    # m.reflect(0)
    # m.reflect(1)
    # m.determinate_bbox()
    # var t0 = getMonoTime()
    # let rez1 = m.pairs_for_periodic_bc1()
    # echo getMonoTime()-t0
    # t0 = getMonoTime()
    # let rez2 = m.pairs_for_periodic_bc()
    # echo getMonoTime()-t0
    discard

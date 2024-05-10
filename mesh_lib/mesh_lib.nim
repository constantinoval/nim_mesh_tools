import ../kfile/lsmodel
import std/[tables, sugar, intsets, sequtils, threadpool, monotimes]

const isparallel = true

type
    Bbox* = tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    Mesh* = ref object
        model: LSmodel = LSmodel()
        tol: float = 1e-6
    Mesh_bc_data = tuple[fixed: int, dx, dy, dz: float, pairs: Table[string, seq[array[2, int]]]]

proc read*(self: Mesh, file_path: string) =
    ##[
        Чтение сетки из файла
    ]##
    self.model.readMesh(file_path)

proc save*(self: Mesh, file_path: string) =
    ##[
        Сохранение сетки в файл
    ]##
    self.model.save(file_path)

proc clear_and_renumber*(self: Mesh) =
    ##[
        Удаляются свободные узлы. Перенумеровываются узлы и элементы
    ]##
    self.model.delete_unreferenced_nodes()
    self.model.renumber_nodes()
    self.model.renumber_shells()
    self.model.renumber_solids()
    self.model.renumber_solidsortho()

proc proceed*(self: Mesh) =
    ##[
        Определяются границы модели и расчитываются объемы конечных элементов
    ]##
    self.model.determinateBbox()
    self.model.calculateElementVolumesParallel()
    self.model.TOL = self.tol

func bbox*(self: Mesh): Bbox =
    ##[
        Границы сеточной модели: tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    ]##
    return self.model.bbox

proc reflect*(self: Mesh, norm: int) =
    ##[
        Отражение модели:
            norm == 0 - относительно плоскости YZ,
            norm == 1 - относительно плоскости XZ,
            norm == 2 - относительно плоскости XY
    ]##
    self.model.reflect(norm=norm, tol=self.tol)

proc translate*(self: Mesh, dx: float=0, dy: float=0, dz: float=0) =
    ##[
        Смещение модели на dx, dy, dz
    ]##
    self.model.translate(dx=dx, dy=dy, dz=dz)

proc pairs_for_periodic_bc*(self: Mesh): Mesh_bc_data =
    ##[
        Поиск пар узлов для периодических граничных условий
    ]##
    proc find_pairs(model: LSmodel, nodes_set1: IntSet, nodes_set2: IntSet): seq[array[2, int]] =
        var set2 = nodes_set2
        for n1 in nodes_set1:
            let n2 = model.nearest_node(n1, set2)
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
    when isparallel:
        let planex = spawn find_pairs(self.model, p_ABFE, p_DCGH)
        let planey = spawn find_pairs(self.model, p_ADHE, p_BCGF)
        let planez = spawn find_pairs(self.model, p_ABCD, p_HGFE)
        let l1x = spawn find_pairs(self.model, l_AD, l_FG)
        let l2x = spawn find_pairs(self.model, l_EH, l_BC)
        let l1y = spawn find_pairs(self.model, l_AB, l_HG)
        let l2y = spawn find_pairs(self.model, l_EF, l_DC)
        let l1z = spawn find_pairs(self.model, l_AE, l_CG)
        let l2z = spawn find_pairs(self.model, l_BF, l_DH)
        result.pairs["planex"] = ^planex
        result.pairs["planey"] = ^planey
        result.pairs["planez"] = ^planez
        result.pairs["linex"] = concat(^l1x, ^l2x)
        result.pairs["liney"] = concat(^l1y, ^l2y)
        result.pairs["linez"] = concat(^l1z, ^l2z)
    else:
        result.pairs["planex"] = find_pairs(self.model, p_ABFE, p_DCGH)
        result.pairs["planey"] = find_pairs(self.model, p_ADHE, p_BCGF)
        result.pairs["planez"] = find_pairs(self.model, p_ABCD, p_HGFE)
        result.pairs["linex"] = concat(find_pairs(self.model, l_AD, l_FG), find_pairs(self.model, l_EH, l_BC))
        result.pairs["liney"] = concat(find_pairs(self.model, l_AB, l_HG), find_pairs(self.model, l_EF, l_DC))
        result.pairs["linez"] = concat(find_pairs(self.model, l_AE, l_CG), find_pairs(self.model, l_BF, l_DH))

    result.pairs["points"] = @[
        [A.toSeq[0], G.toSeq[0]],
        [B.toSeq[0], H.toSeq[0]],
        [D.toSeq[0], F.toSeq[0]],
        [E.toSeq[0], C.toSeq[0]],
    ]

when isMainModule:
    var m = new(Mesh)
    echo "Reading..."
    m.read("./big_test.k")
    echo "Clearing and renumbering..."
    m.clear_and_renumber()
    echo "Calculating volumes..."
    m.proceed()
    # echo m.bbox
    # echo m.model.modelInfo()
    # m.reflect(0)
    # echo m.model.modelInfo()
    # echo m.model.solids[1].volume
    # m.save("1.k")
    let t0 = getMonoTime()
    echo "Processing bcs..."
    let rez = m.pairs_for_periodic_bc()
    echo getMonoTime() - t0
    echo "All done..."

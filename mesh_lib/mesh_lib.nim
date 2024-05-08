import ../kfile/lsmodel
import std/[tables, sugar, intsets]

type
    Bbox* = tuple[minx: float, miny: float, minz: float, maxx: float, maxy: float, maxz: float]
    Mesh* = ref object
        model: LSmodel = LSmodel()
        tol: float = 1e6

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

proc pairs_for_periodic_bc*(self: Mesh): Table[string, seq[array[2, int]]] =
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
    let xmin = self.model.planeXmin().toIntSet
    let ymin = self.model.planeYmin().toIntSet
    let zmin = self.model.planeZmin().toIntSet
    let xmax = self.model.planeXmax().toIntSet
    let ymax = self.model.planeYmax().toIntSet
    let zmax = self.model.planeZmax().toIntSet

    let q = find_pairs(self.model, [1, 2, 3].toIntSet, [4, 5, 6].toIntSet)
    result["A"] = q


when isMainModule:
    var m = new(Mesh)
    m.read("./renumbering_test.k")
    echo m.model.modelInfo()
    m.clear_and_renumber()
    m.reflect(0)
    m.proceed()
    echo m.model.modelInfo()
    echo m.model.solids[1].volume
    echo m.bbox
    m.save("1.k")
    echo m.pairs_for_periodic_bc()

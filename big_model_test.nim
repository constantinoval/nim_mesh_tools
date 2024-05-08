import kfile/lsmodel

when isMainModule:
    var ls = LSmodel()
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
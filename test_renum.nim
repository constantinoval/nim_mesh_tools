import kfile/lsmodel

when isMainModule:
  var ls = LSmodel()
  echo "Reading..."
  ls.readMesh("./renumbering_test.k")
  echo "renumberring nodes..."
  ls.renumber_nodes()
  echo "renumberring solids..."
  ls.renumber_solids()
  echo "Removing unreferenced nodes..."
  echo "Deleted unreferenced nodes: ", ls.delete_unreferenced_nodes()
  echo "Saving..."
  ls.save("./ren_rez.k")

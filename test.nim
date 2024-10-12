import kfile/lsmodel
import std/monotimes

var m = LSmodel()
m.readMeshSerial("big_test.k")
echo m.modelInfo
var t0 = getMonoTime()
m.saveSerial("mesh_s.k")
echo getMonoTime()-t0
t0 = getMonoTime()
m.saveParallel("mesh_p.k")
echo getMonoTime()-t0
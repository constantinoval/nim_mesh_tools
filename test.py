import mesh_lib

m = mesh_lib.Mesh()
m.read('mesh1.k')
print(m.info())
print(m.parts_numbers())
print(m.parts_volumes())
m.translate(dx=10.0)
import mesh_lib

m = mesh_lib.Mesh()
m.read('mesh.k')
print(m.info())
m.calculate_element_volumes(2)
print(m.parts_numbers())
print(m.parts_volumes())
m.translate(dx=10.0)
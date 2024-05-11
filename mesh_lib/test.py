import mesh_lib

m = mesh_lib.Mesh()
print("Reading...")
m.read('./renumbering_test.k')
print(m.info())
print("Clearing and renumbering...")
m.clear_and_renumber()
print("Calculating volumes...")
m.proceed()
print("Model bbox: ", m.bbox())
# echo m.model.modelInfo()
# m.reflect(0)
# echo m.model.modelInfo()
# echo m.model.solids[1].volume
# m.save("1.k")
print("Processing bcs...")
fixed, dx, dy, dz, pairs = m.pairs_for_periodic_bc()
print("All done...")
print(f"{fixed=}")
print(f"{dx=}")
print(f"{dy=}")
print(f"{dz=}")
print("Saving...")
m.save("1.k")



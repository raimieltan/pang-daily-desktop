class_name TrackMaterials
## Materials and small meshes for generated tracks, in the manga style (docs/ART_DIRECTION.md).


static func road() -> ShaderMaterial:
	return MangaArt.road()


## Indexed by `TrackBuilder.Mat`: asphalt, concrete, gravel, rock, dirt.
static func road_set() -> Array[Material]:
	return [
		MangaArt.road(),
		MangaArt.world(0.04, MangaArt.Pattern.DOTS, 0.4),
		MangaArt.world(0.3, MangaArt.Pattern.STIPPLE, 0.4),
		MangaArt.world(0.45, MangaArt.Pattern.HATCH, 0.4, 1.0),
		MangaArt.world(0.2, MangaArt.Pattern.STIPPLE, 0.45, 1.0),
	]


static func terrain() -> ShaderMaterial:
	return MangaArt.world(0.16, MangaArt.Pattern.DOTS, 0.5, 1.0)


static func guardrail() -> ShaderMaterial:
	return MangaArt.world(0.0, MangaArt.Pattern.DOTS, 0.35)


## Low-poly Japanese cedar (sugi): trunk plus two stacked cones, one mesh with two surfaces.
static func cedar_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.25
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var leaves := CylinderMesh.new()
	leaves.top_radius = 0.0
	leaves.bottom_radius = 2.3
	leaves.height = 11.0
	leaves.radial_segments = 7
	leaves.rings = 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.5, 0)))
	st.set_material(MangaArt.world(0.92, MangaArt.Pattern.HATCH))
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.append_from(leaves, 0, Transform3D(Basis(), Vector3(0, 8.0, 0)))
	st2.set_material(MangaArt.world(0.55, MangaArt.Pattern.HATCH, 0.4))
	st2.commit(mesh)
	return mesh

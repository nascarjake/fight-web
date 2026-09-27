class_name LabStage
extends Node3D

var camera: Camera3D
var debug_root: Node3D
var effects: Array[Dictionary] = []
var reach_guides: Array[MeshInstance3D] = []

func show_reach(fighters: Array[Dictionary], reaches: Array, enabled: bool) -> void:
 for index in range(2):
  if reach_guides.size() <= index:
   reach_guides.append(_box(Vector3.ZERO, Vector3(1, 0.012, 0.045), Color("88d9ff") if index == 0 else Color("f6a46d"), 0.3))
  var guide: MeshInstance3D = reach_guides[index]
  guide.visible = enabled
  var fighter: Dictionary = fighters[index]
  var reach: float = reaches[index]
  guide.scale.x = reach
  guide.position = Vector3(fighter["position"].x + float(fighter["facing"]) * reach * 0.5, 0.018, 0.22 + index * 0.08)

func _ready() -> void:
 var environment = Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color('#12171e')
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color('#cbd8ef')
 environment.ambient_light_energy = 0.65
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 var world_environment = WorldEnvironment.new()
 world_environment.environment = environment
 add_child(world_environment)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-35,-25,0)
 sun.light_color = Color('#fff3e1')
 sun.light_energy = 1.7
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 20
 add_child(sun)
 var rim = DirectionalLight3D.new()
 rim.rotation_degrees = Vector3(-30,150,0)
 rim.light_color = Color('#83c8ff')
 rim.light_energy = 1.1
 add_child(rim)
 _box(Vector3(0,-0.08,0),Vector3(18,0.15,12),Color('#1e252d'))
 for x in range(-9,10):
  _box(Vector3(x,0.003,0),Vector3(0.012,0.006,12),Color('#454f5a'))
 for z in range(-6,7):
  _box(Vector3(0,0.003,z),Vector3(18,0.006,0.012),Color('#454f5a'))
 _box(Vector3(0,0.008,0),Vector3(18,0.008,0.025),Color('#d8ef58'),1.0)
 for x in [-6.0,6.0]:
  _box(Vector3(x,1.8,-3.4),Vector3(0.16,3.6,0.2),Color('#313944'))
  _box(Vector3(x,1.8,-3.25),Vector3(0.035,3.4,0.035),Color('#d8ef58'),1.4)
 _box(Vector3(0,3.6,-3.4),Vector3(12.2,0.16,0.2),Color('#313944'))
 for x in [-4.0,4.0]:
  _box(Vector3(x,0.5,-3),Vector3(1.25,1,0.5),Color('#202731'))
  _box(Vector3(x,0.52,-2.72),Vector3(0.8,0.03,0.015),Color('#91bdcd'),1)
 var mark = Label3D.new()
 mark.text = "RIFT / RIOT"
 mark.font_size = 48
 mark.pixel_size = 0.004
 mark.modulate = Color('#88988c')
 mark.position = Vector3(0,2.4,-3.1)
 mark.outline_size = 0
 add_child(mark)
 var subtitle = Label3D.new()
 subtitle.text = "COMBAT RESEARCH  /  BAY 01"
 subtitle.font_size = 25
 subtitle.pixel_size = 0.004
 subtitle.modulate = Color('#708084')
 subtitle.position = Vector3(0,2.12,-3.08)
 subtitle.outline_size = 0
 add_child(subtitle)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 4.0
 camera.position = Vector3(0,2.3,8)
 add_child(camera)
 camera.look_at(Vector3(0,1.1,0))
 camera.current = true
 debug_root = Node3D.new()
 add_child(debug_root)

func _box(at:Vector3,size_value:Vector3,color:Color,emission:float=0.0) -> MeshInstance3D:
 var node = MeshInstance3D.new()
 var mesh = BoxMesh.new()
 mesh.size = size_value
 var mat = StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = 0.75
 if emission > 0:
  mat.emission_enabled = true
  mat.emission = color
  mat.emission_energy_multiplier = emission
 mesh.material = mat
 node.mesh = mesh
 node.position = at
 add_child(node)
 return node

func draw_boxes(hits:Array,hurt:Array,invulnerable:Array,enabled:bool) -> void:
 for child in debug_root.get_children():
  child.queue_free()
 if not enabled:
  return
 for rect in hurt:
  _debug_rect(rect,Color('#4ae1ad'),0.045)
 for rect in hits:
  _debug_rect(rect,Color('#ff596b'),0.10)
 for rect in invulnerable:
  _debug_rect(rect,Color('#67baff'),0.06)

func _debug_rect(rect:Rect2,color:Color,alpha:float) -> void:
 var geometry = ImmediateMesh.new()
 var mat = StandardMaterial3D.new()
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.albedo_color = color
 mat.no_depth_test = true
 var x = rect.position.x
 var y = rect.position.y
 var w = rect.size.x
 var h = rect.size.y
 var z = 0.33
 var points = [Vector3(x,y,z),Vector3(x+w,y,z),Vector3(x+w,y+h,z),Vector3(x,y+h,z)]
 geometry.surface_begin(Mesh.PRIMITIVE_LINES,mat)
 for i in range(4):
  geometry.surface_add_vertex(points[i])
  geometry.surface_add_vertex(points[(i+1)%4])
 geometry.surface_end()
 var outline = MeshInstance3D.new()
 outline.mesh = geometry
 debug_root.add_child(outline)
 var fill = MeshInstance3D.new()
 var quad = QuadMesh.new()
 quad.size = rect.size
 var fill_mat = StandardMaterial3D.new()
 fill_mat.albedo_color = Color(color,alpha)
 fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 fill_mat.no_depth_test = true
 fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 quad.material = fill_mat
 fill.mesh = quad
 fill.position = Vector3(x+w/2,y+h/2,z-0.01)
 debug_root.add_child(fill)

func impact(at:Vector2,blocked:bool=false) -> void:
 for i in range(14):
  var node = MeshInstance3D.new()
  var mesh = SphereMesh.new()
  mesh.radius = 0.024
  mesh.height = 0.048
  mesh.radial_segments = 6
  mesh.rings = 3
  var mat = StandardMaterial3D.new()
  mat.albedo_color = Color('#78ccff') if blocked else Color('#fff2a0')
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  mesh.material = mat
  node.mesh = mesh
  node.position = Vector3(at.x,at.y,0.1)
  add_child(node)
  effects.append({'node':node,'velocity':Vector3(randf_range(-2,2),randf_range(-1,3),randf_range(-0.2,0.6)),'life':0.22})

func _process(delta:float) -> void:
 for i in range(effects.size()-1,-1,-1):
  var effect = effects[i]
  effect.life -= delta
  effect.node.position += effect.velocity*delta
  effect.node.scale = Vector3.ONE*maxf(0.05,effect.life/0.22)
  if effect.life <= 0:
   effect.node.queue_free()
   effects.remove_at(i)

func frame_fighters(fighters:Array[Dictionary]) -> void:
 if camera==null or fighters.size()<2:return
 var a:Vector2=fighters[0].position
 var b:Vector2=fighters[1].position
 var center:float=(a.x+b.x)*0.5
 var viewport_size:Vector2=get_viewport().get_visible_rect().size
 var aspect:float=viewport_size.x/maxf(1.0,viewport_size.y)
 camera.size=maxf(4.0,(absf(a.x-b.x)+2.5)/aspect)
 camera.position=Vector3(center,2.3,8)
 camera.look_at(Vector3(center,1.15,0))

extends SceneTree
func _initialize() -> void:
 var model = load("res://assets/characters/AvatarSample_C.vrm").instantiate()
 root.add_child(model)
 print("MODEL ROOT ", model.name)
 model.print_tree_pretty()
 var skeletons = model.find_children("*", "Skeleton3D", true, false)
 for skeleton in skeletons:
  print("SKELETON ", model.get_path_to(skeleton), " COUNT ", skeleton.get_bone_count())
  for i in range(skeleton.get_bone_count()):
   if skeleton.get_bone_name(i) in ["Hips", "Spine", "Chest", "Head", "LeftUpperArm", "LeftLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperArm", "LeftFoot"]:
    print(skeleton.get_bone_name(i), " rest ", skeleton.get_bone_rest(i))
 quit()

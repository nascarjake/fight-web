extends SceneTree
## Native AnimationPlayer checks for every local fighter and cinematic.

var failures := 0
var checks := 0
const IDS := ["kai","neon","yuki","ivy","rook","atlas","zero","vex","sora","raijin"]
const TECHNIQUES := ["jab","cross","low_kick","launcher","dodge","burst","finisher"]

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func _run() -> void:
	var actor := AvatarActor.new()
	root.add_child(actor)
	var silhouettes: Dictionary = {}
	for id in IDS:
		actor.position = Vector3.ZERO
		actor.setup(false,id)
		_check(actor.fighter_id == id and actor.skeleton != null and actor.player != null,id+" loads its own imported model")
		if actor.skeleton == null or actor.player == null: continue
		_check(actor.get_child_count() == 2,id+" switching leaves exactly model and player")
		_check(actor.scale.is_equal_approx(Vector3.ONE),id+" actor keeps simulation world scale")
		var bounds := AABB()
		var has_bounds := false
		for node in actor.find_children("*","MeshInstance3D",true,false):
			var box: AABB = node.global_transform * node.get_aabb()
			bounds = bounds.merge(box) if has_bounds else box
			has_bounds = true
		_check(absf(bounds.size.y-1.72)<.001,id+" visual resting height is canonical")
		_check(absf(bounds.position.y)<.001,id+" visual resting floor is aligned")
		for foot_name in ["LeftFoot","RightFoot"]:
			var foot := actor.skeleton.find_bone(foot_name)
			var foot_world := actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(foot).origin)
			_check(foot_world.y>.07 and foot_world.y<.3,id+" posed ankle stays above the floor")
		_check(ResourceLoader.exists("res://assets/ui/roster/"+id+".png"),id+" has its local portrait")
		for clip in ["idle","showcase","victory","cinematic"]+TECHNIQUES:
			_check(actor.player.has_animation(id+"_"+clip),id+" has authored "+clip)
		_check(is_equal_approx(actor.player.get_animation(id+"_cinematic").length,3.5),id+" cinematic matches director duration")
		var signature := PackedFloat32Array()
		for technique in TECHNIQUES:
			var move := MoveData.new()
			move.id = technique
			move.animation_name = id+"_"+technique
			move.startup = 10
			move.active = 5
			move.recovery = 17
			move.animation_blend_frames = 3
			var state := {"position":Vector2(.5,.2),"facing":-1,"state":"active","move":move,"move_frame":0}
			for frame in move.total_frames():
				state.move_frame = frame
				actor.apply_state(state)
				var expected := actor.player.get_animation(move.animation_name).length*float(frame)/float(move.total_frames())
				_check(absf(actor.player.current_animation_position-expected)<.0001,id+" "+technique+" exact simulation sample")
			actor.preview_move(move,move.startup)
			var sample := _pose_snapshot(actor)
			actor.preview_move(move,move.total_frames()-1)
			actor.preview_move(move,move.startup)
			_check(sample == _pose_snapshot(actor),id+" "+technique+" independent scrub")
			for tick in 8: actor.apply_state(state,false)
			_check(sample == _pose_snapshot(actor),id+" "+technique+" all-bone hitstop freeze")
			for bone_name in ["LeftHand","RightHand","LeftFoot","RightFoot"]:
				var point := actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone_name)).origin
				signature.append_array(PackedFloat32Array([point.x,point.y,point.z]))
		silhouettes[id] = signature
		if id in ["kai", "neon"]:
			for authored: MoveData in FighterCatalog.moves(id):
				if not authored.animated_hitbox: continue
				var peak := authored.startup + authored.active / 2
				for facing in [-1, 1]:
					actor.apply_state({"position": Vector2.ZERO, "facing": facing, "move": authored, "move_frame": peak, "state": "active"})
					actor.preview_move(authored, peak)
					var anchor := actor.presentation_anchor(authored.visual_anchor)
					var projected := Vector2(anchor.x * facing, anchor.y)
					_check(authored.attack_rect_at(peak).grow(0.08).has_point(projected), id + " " + authored.id + " contact box covers striking limb in either facing")
		for role in ["attacker","victim"]:
			var changing_pose := false
			var last_pose := _pose_snapshot(actor)
			for frame in range(0,211,7):
				var time := float(frame)/60.0
				actor.present_cinematic(id,time,role)
				var current := _pose_snapshot(actor)
				changing_pose = changing_pose or current != last_pose
				last_pose = current
				for bone in actor.skeleton.get_bone_count():
					var transform := actor.skeleton.get_bone_global_pose(bone)
					_check(transform.origin.is_finite() and transform.basis.is_finite(),id+" finite cinematic bone")
				var motion := AvatarActor.cinematic_motion(id,time)
				_check(motion.is_finite() and absf(motion.x)<=.6001 and motion.y<=1.01,id+" bounded cinematic displacement")
			_check(changing_pose,id+" "+role+" cinematic articulates")
		for presentation in ["showcase","victory"]:
			actor.present(presentation,.7,.12)
			_check(actor.player.current_animation == id+"_"+presentation,id+" resolves own "+presentation)
		print("ROSTER %s: %d bones, %d authored clips, cinematic and move frames checked." % [id,actor.skeleton.get_bone_count(),actor.animation_names().size()])
	for i in IDS.size():
		for j in range(i+1,IDS.size()):
			_check(silhouettes[IDS[i]] != silhouettes[IDS[j]],IDS[i]+" and "+IDS[j]+" have different technique silhouettes")
	actor.set_fighter("kai")
	actor.set_fighter("kai")
	_check(actor.get_child_count()==2,"repeated same-character selection preserves one actor")
	actor.free()
	await process_frame
	print("Roster animation: %d checks; %d failures." % [checks,failures])
	quit(failures)

func _pose_snapshot(actor: AvatarActor) -> PackedFloat32Array:
	var snapshot := PackedFloat32Array()
	for bone in actor.skeleton.get_bone_count():
		var q := actor.skeleton.get_bone_pose_rotation(bone)
		var p := actor.skeleton.get_bone_pose_position(bone)
		snapshot.append_array(PackedFloat32Array([q.x,q.y,q.z,q.w,p.x,p.y,p.z]))
	return snapshot

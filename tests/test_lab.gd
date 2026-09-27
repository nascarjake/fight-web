extends SceneTree
const Roster=preload('res://combat/FighterCatalog.gd')
var failures:int=0
func _initialize() -> void:
 call_deferred('_run')
func check(condition:bool,message:String) -> void:
 if not condition:
  failures+=1
  push_error(message)
func _run() -> void:
 var scene = load('res://scenes/combat_lab.tscn') as PackedScene
 check(scene!=null,'Lab scene loads')
 if scene==null:quit(1);return
 var lab = scene.instantiate()
 root.add_child(lab)
 await process_frame
 lab.playing=false
 check(lab.actors.size()==2,'Two imported actors exist')
 check(lab.actors[0].skeleton.get_bone_count()>50,'Real humanoid skeleton imported')
 check(lab.actors[0].animation_names().has('kai_jab'),'Character-authored attack available')
 lab._scrub(6)
 check(lab.preview_frame==6,'Frame scrubbing is exact')
 check(lab.simulation.fighters[0].move_frame==6,'Visible and simulation preview frame agree')
 var move = lab.selected
 var start=move.startup
 var active=move.active
 var recover=move.recovery
 move.startup=0
 move.active=0
 move.recovery=0
 lab._move_changed(move)
 lab._step_once()
 check(lab.preview_frame==0,'Invalid intermediate timing cannot crash preview')
 move.startup=start
 move.active=active
 move.recovery=recover
 lab._move_changed(move)
 lab._set_mode('training')
 lab.playing=false
 lab.simulation.fighters[0].position=Vector2(-.5,0)
 lab.simulation.fighters[1].position=Vector2(.5,0)
 lab.action_queue[0]='cross'
 lab._training_tick()
 check(lab.selected.id=='cross','Training current move synchronizes selected move')
 check(lab.workbench.selected_move().id=='cross','Editor and training move agree')
 for i in range(20):lab._training_tick()
 check(lab.simulation.fighters[1].hp<100,'Live scene simulation resolves contact')
 lab._scrub(10)
 check(lab.mode=='preview','Scrubbing enters preview')
 check(lab.selected.id=='cross','Scrubbing preserves current selected move')
 check(lab.simulation.fighters[1].hp==100,'Preview transition resets combat state')
 check(lab.health_bars[1].value==100,'Preview resets HUD health')
 lab._reset()
 check(lab.preview_frame==0,'Reset returns to frame zero')
 var editor_children:int=lab.workbench.get_child_count()
 for profile:Dictionary in Roster.all():
  lab.select_fighter(profile.id)
  check(lab.actors[0].fighter_id==profile.id and lab.actors[1].fighter_id==profile.id,'Both lab actors switch to '+profile.id)
  check(lab.workbench.save_namespace==profile.id,'Saves use the selected fighter namespace')
  check(lab.selected.animation_name.begins_with(profile.id+'_'),'Preview uses selected fighter techniques')
  check(lab.simulation.fighters[0].fighter_id==profile.id and lab.simulation.fighters[1].fighter_id==profile.id,'Training uses both fighter profiles')
  check(lab.workbench.get_child_count()==editor_children,'Switching fighters reuses editor controls')
  lab._scrub(4)
  check(lab.actors[0].player.current_animation==lab.selected.animation_name,'Scrub selects the character-specific animation')
 lab.select_fighter('neon')
 var edited_damage:float=lab.selected.damage+3
 lab.selected.damage=edited_damage
 lab.select_fighter('kai')
 lab.select_fighter('neon')
 check(lab.selected.damage==edited_damage,'Unsaved edits remain with their fighter while switching')
 lab._set_mode('training')
 lab.playing=false
 lab.simulation.fighters[0].position=Vector2(-3,0)
 lab.simulation.fighters[1].position=Vector2(3,0)
 lab.action_queue[0]='burst'
 for i in range(30):lab._training_tick()
 check(not lab.simulation.projectile_hitboxes().is_empty(),'Training runs character projectiles for box debugging')
 lab.select_fighter('kai')
 lab._set_mode('training')
 lab.playing=false
 lab.simulation.fighters[0].position=Vector2(-.45,0)
 lab.simulation.fighters[1].position=Vector2(.45,0)
 lab.action_queue[0]='finisher'
 for i in range(100):lab._training_tick()
 check(lab.simulation.pending_cinematic.is_empty(),'Training resolves confirmed cinematics immediately')
 check(lab.simulation.fighters[1].hp<100,'Training finisher applies resolved contact damage')
 lab.queue_free()
 await process_frame
 print('LAB INTEGRATION failures: ',failures)
 quit(0 if failures==0 else 1)

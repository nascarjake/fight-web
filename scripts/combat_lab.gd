extends Control

const Actor = preload('res://scripts/avatar_actor.gd')
const Stage = preload('res://scripts/lab_stage.gd')
const Simulation = preload('res://combat/FightSimulation.gd')
const Catalog = preload('res://combat/MoveCatalog.gd')
const Roster = preload('res://combat/FighterCatalog.gd')
const Workbench = preload('res://editor/move_workbench.gd')
var simulation:FightSimulation
var moves:Array[MoveData] = []
var actors:Array = []
var stage:LabStage
var workbench:MoveWorkbench
var selected:MoveData
var preview_frame:int = 0
var playing:bool = true
var mode:String = 'preview'
var dummy:String = 'stand'
var debug_visible:bool = true
var action_queue:Array[String] = ['','']
var power_queue:Array[bool] = [false,false]
var viewport:SubViewport
var frame_label:Label
var phase_label:Label
var mode_label:Label
var contact_label:Label
var detail_label:Label
var health_bars:Array[ProgressBar] = []
var guard_bars:Array[ProgressBar] = []
var energy_bars:Array[ProgressBar] = []
var history_label:Label
var history:Array[String] = []
var tick_label:Label
var notification_time:float = 0
var captured:bool = false
var selected_fighter:String = 'kai'
var fighter_picker:OptionButton
var fighter_labels:Array[Label] = []
var _fighter_moves:Dictionary = {}

func _ready() -> void:
 _theme()
 moves = Roster.moves(selected_fighter)
 simulation = Simulation.new()
 _configure_simulation()
 simulation.reset()
 selected = moves[0]
 _layout()
 stage = Stage.new()
 viewport.add_child(stage)
 for i in range(2):
  var actor = Actor.new()
  stage.add_child(actor)
  actor.setup(i==1,selected_fighter)
  actors.append(actor)
 workbench.save_namespace=selected_fighter
 workbench.setup(moves)
 _fighter_moves[selected_fighter]=moves
 workbench.set_animation_names(actors[0].animation_names())
 workbench.move_selected.connect(_select_move)
 workbench.move_changed.connect(_move_changed)
 workbench.scrubbed.connect(_scrub)
 workbench.playback_toggled.connect(func(value:bool):playing=value)
 workbench.step_requested.connect(_step_once)
 workbench.reset_requested.connect(_reset)
 workbench.debug_toggled.connect(func(value:bool):debug_visible=value;_refresh_boxes())
 workbench.mode_changed.connect(_set_mode)
 workbench.dummy_changed.connect(func(value:String):dummy=value)
 _reset()
 workbench.set_playing(true)
 _update_preview()
 if '--capture' in OS.get_cmdline_user_args():
  _capture_later()

func _configure_simulation() -> void:
 var profile:Dictionary=Roster.get_fighter(selected_fighter)
 for i in range(2):
  simulation.set_fighter_profile(i,profile)
  simulation.set_fighter_moves(i,moves)

func select_fighter(id:String) -> void:
 var profile:Dictionary=Roster.get_fighter(id)
 selected_fighter=str(profile.id)
 var cached:bool=_fighter_moves.has(selected_fighter)
 if cached:moves=_fighter_moves[selected_fighter]
 else:
  moves=Roster.moves(selected_fighter)
  _fighter_moves[selected_fighter]=moves
 selected=moves[0]
 for i in range(2):actors[i].setup(i==1,selected_fighter)
 _configure_simulation()
 workbench.save_namespace=selected_fighter
 workbench.set_animation_names(actors[0].animation_names())
 workbench.setup(moves,not cached)
 for i in range(2):fighter_labels[i].text='%02d  %s%s' % [i+1,profile.name,' / DUMMY' if i==1 else '']
 for i in range(fighter_picker.item_count):
  if fighter_picker.get_item_metadata(i)==selected_fighter:fighter_picker.select(i)
 _reset()
 workbench.set_status('%s · %s · saves are separate for this fighter.' % [profile.name,profile.archetype])

func _fighter_selected(index:int) -> void:
 select_fighter(str(fighter_picker.get_item_metadata(index)))

func _theme() -> void:
 var t = Theme.new()
 var font = SystemFont.new()
 font.font_names = PackedStringArray(['Avenir Next','Helvetica Neue','Arial'])
 t.default_font = font
 t.default_font_size = 14
 t.set_color('font_color','Label',Color('#e7eae0'))
 t.set_color('font_color','Button',Color('#e7eae0'))
 var panel = StyleBoxFlat.new()
 panel.bg_color = Color('#171c22')
 t.set_stylebox('panel','PanelContainer',panel)
 for state_name in ['normal','hover','pressed','focus']:
  var box = StyleBoxFlat.new()
  box.bg_color = Color('#2c333b') if state_name=='hover' else Color('#222830')
  box.border_color = Color('#d8ed53') if state_name=='focus' else Color('#404954')
  box.set_border_width_all(1)
  box.content_margin_left = 10
  box.content_margin_right = 10
  box.content_margin_top = 8
  box.content_margin_bottom = 8
  t.set_stylebox(state_name,'Button',box)
 theme = t

func _label(text_value:String,size_value:int=14,color:Color=Color('#e4e8e1')) -> Label:
 var label = Label.new()
 label.text = text_value
 label.add_theme_font_size_override('font_size',size_value)
 label.add_theme_color_override('font_color',color)
 return label

func _layout() -> void:
 var background = ColorRect.new()
 background.color = Color('#10151a')
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(background)
 var split = HBoxContainer.new()
 split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 split.add_theme_constant_override('separation',0)
 add_child(split)
 var left = VBoxContainer.new()
 left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 left.add_theme_constant_override('separation',0)
 split.add_child(left)
 var top_panel = PanelContainer.new()
 top_panel.custom_minimum_size.y = 76
 left.add_child(top_panel)
 var top_margin = MarginContainer.new()
 for side in ['left','right']:
  top_margin.add_theme_constant_override('margin_'+side,16)
 top_panel.add_child(top_margin)
 var top = HBoxContainer.new()
 top.add_theme_constant_override('separation',10)
 top_margin.add_child(top)
 var brand = _label('RIFT//RIOT',22,Color('#d8ed53'))
 top.add_child(brand)
 var title = _label('COMBAT LAB',12)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 top.add_child(title)
 fighter_picker=OptionButton.new()
 fighter_picker.custom_minimum_size=Vector2(105,38)
 fighter_picker.tooltip_text='Select the fighter to preview, train and edit.'
 for profile:Dictionary in Roster.all():
  fighter_picker.add_item(profile.name)
  var index:int=fighter_picker.item_count-1
  fighter_picker.set_item_metadata(index,profile.id)
  fighter_picker.set_item_tooltip(index,profile.archetype)
 fighter_picker.item_selected.connect(_fighter_selected)
 top.add_child(fighter_picker)
 mode_label = _label('MOVE PREVIEW',11,Color('#bac5ce'))
 top.add_child(mode_label)
 var game_menu = Button.new()
 game_menu.text = 'GAME MENU'
 game_menu.pressed.connect(func():get_tree().change_scene_to_file('res://scenes/game.tscn'))
 top.add_child(game_menu)
 var viewport_stack = Control.new()
 viewport_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
 viewport_stack.custom_minimum_size = Vector2(620,400)
 viewport_stack.focus_mode=Control.FOCUS_ALL
 viewport_stack.gui_input.connect(func(event:InputEvent):
  if event is InputEventMouseButton and event.pressed:
   viewport_stack.grab_focus()
 )
 left.add_child(viewport_stack)
 var container = SubViewportContainer.new()
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.stretch = true
 container.mouse_filter=Control.MOUSE_FILTER_IGNORE
 viewport_stack.add_child(container)
 viewport = SubViewport.new()
 viewport.size = Vector2i(1000,650)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_4X
 container.add_child(viewport)
 var hud_margin = MarginContainer.new()
 hud_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 hud_margin.add_theme_constant_override('margin_left',28)
 hud_margin.add_theme_constant_override('margin_right',28)
 hud_margin.add_theme_constant_override('margin_top',25)
 hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
 viewport_stack.add_child(hud_margin)
 var hud = HBoxContainer.new()
 hud.add_theme_constant_override('separation',50)
 hud_margin.add_child(hud)
 for i in range(2):
  var column = VBoxContainer.new()
  column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  hud.add_child(column)
  var name_label = _label('01  KAI' if i==0 else '02  KAI / DUMMY',13,Color('#d8ed53') if i==0 else Color('#b8d8f0'))
  if i==1:name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  column.add_child(name_label)
  fighter_labels.append(name_label)
  health_bars.append(_bar(column,Color('#d8ed53'),8))
  guard_bars.append(_bar(column,Color('#91b8d1'),3))
  energy_bars.append(_bar(column,Color('#be8cfd'),3))
 contact_label = _label('',27,Color('#fff0b0'))
 contact_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 contact_label.position = Vector2(-180,125)
 contact_label.size.x = 360
 contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 contact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 viewport_stack.add_child(contact_label)
 var legend = _label('■ HURTBOX     ■ HITBOX     ■ INVULNERABLE',11,Color('#c2d0cd'))
 legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 legend.position = Vector2(28,-34)
 viewport_stack.add_child(legend)
 var telemetry_panel = PanelContainer.new()
 telemetry_panel.custom_minimum_size.y = 135
 left.add_child(telemetry_panel)
 var margin = MarginContainer.new()
 for side in ['left','right','top','bottom']:
  margin.add_theme_constant_override('margin_'+side,20)
 telemetry_panel.add_child(margin)
 var telemetry = VBoxContainer.new()
 telemetry.add_theme_constant_override('separation',8)
 margin.add_child(telemetry)
 var row = HBoxContainer.new()
 row.add_theme_constant_override('separation',20)
 telemetry.add_child(row)
 frame_label = _label('FRAME 00',24,Color('#d8ed53'))
 row.add_child(frame_label)
 phase_label = _label('STARTUP',14)
 phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(phase_label)
 tick_label = _label('60 Hz  /  FIXED STEP',12,Color('#9ca9b5'))
 row.add_child(tick_label)
 detail_label = _label('',12,Color('#bdc6ce'))
 telemetry.add_child(detail_label)
 history_label = _label('CONTACT LOG  /  No contact yet',12,Color('#8d9d9d'))
 history_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 telemetry.add_child(history_label)
 var controls = _label('  A/D MOVE   W JUMP   S CROUCH   J/K/L ATTACK   I BLOCK   SHIFT DODGE   U LAUNCH   O BURST   H POWER   P FINISHER',10,Color('#a5b2ba'))
 controls.custom_minimum_size.y = 35
 left.add_child(controls)
 workbench = Workbench.new()
 workbench.custom_minimum_size.x = 380
 workbench.size_flags_horizontal = Control.SIZE_FILL
 split.add_child(workbench)

func _bar(parent:Node,color:Color,height:float) -> ProgressBar:
 var bar = ProgressBar.new()
 bar.custom_minimum_size.y = height
 bar.show_percentage = false
 bar.value = 100
 var bg = StyleBoxFlat.new()
 bg.bg_color = Color('#343e48')
 var fill = StyleBoxFlat.new()
 fill.bg_color = color
 bar.add_theme_stylebox_override('background',bg)
 bar.add_theme_stylebox_override('fill',fill)
 parent.add_child(bar)
 return bar

func _set_mode(value:String) -> void:
 mode = value
 mode_label.text = 'MOVE PREVIEW' if mode=='preview' else 'LIVE TRAINING'
 _reset()
 playing = true
 workbench.set_playing(true)
 workbench.set_status('Scrub a frame or edit the move.' if mode=='preview' else 'Click the arena, then use A/D and J/K/L. I blocks; Shift dodges.')

func _select_move(move:MoveData) -> void:
 selected = move
 preview_frame = 0
 if mode=='preview':_update_preview()

func _move_changed(move:MoveData) -> void:
 selected = move
 _configure_simulation()
 preview_frame = clampi(preview_frame,0,maxi(0,selected.total_frames()-1))
 if mode=='preview':_update_preview()

func _scrub(frame:int) -> void:
 if mode!='preview':
  _set_mode('preview')
  workbench.set_mode('preview')
 playing=false
 workbench.set_playing(false)
 preview_frame=clampi(frame,0,maxi(0,selected.total_frames()-1))
 _update_preview()

func _step_once() -> void:
 playing=false
 workbench.set_playing(false)
 if mode=='preview':
  preview_frame=(preview_frame+1)%maxi(1,selected.total_frames())
  _update_preview()
 else:
  _training_tick()

func _reset() -> void:
 simulation.reset()
 _configure_simulation()
 preview_frame=0
 action_queue=['','']
 power_queue=[false,false]
 history.clear()
 history_label.text='CONTACT LOG  /  No contact yet'
 contact_label.text=''
 for i in range(2):
  actors[i].reset_pose()
  actors[i].apply_state(simulation.fighters[i],false)
  health_bars[i].value=100
  guard_bars[i].value=100
  energy_bars[i].value=100
 if mode=='preview':_update_preview()
 else:_update_training_display()

func _physics_process(_delta:float) -> void:
 if not is_instance_valid(workbench):return
 if playing:
  if mode=='preview':
   preview_frame=(preview_frame+1)%maxi(1,selected.total_frames())
   _update_preview()
  else:_training_tick()
 notification_time=maxf(0,notification_time-1.0/60.0)
 if notification_time<=0:contact_label.text=''

func _training_tick() -> void:
 var focus = get_viewport().gui_get_focus_owner()
 var editing:bool = focus is LineEdit or focus is TextEdit or focus is SpinBox
 var p1:Dictionary = {'axis':0.0,'jump':false,'crouch':false,'block':false,'action':action_queue[0],'power':power_queue[0]}
 var p2:Dictionary = {'axis':0.0,'jump':false,'crouch':false,'block':dummy=='block','action':action_queue[1],'power':power_queue[1]}
 if not editing:
  p1.axis=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
  p1.jump=Input.is_physical_key_pressed(KEY_W)
  p1.crouch=Input.is_physical_key_pressed(KEY_S)
  p1.block=Input.is_physical_key_pressed(KEY_I)
  p2.axis=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
  p2.jump=Input.is_physical_key_pressed(KEY_UP)
  p2.crouch=Input.is_physical_key_pressed(KEY_DOWN)
  p2.block=p2.block or Input.is_physical_key_pressed(KEY_0)
 if dummy=='attack':
  var distance = simulation.fighters[0].position.x-simulation.fighters[1].position.x
  if absf(distance)>1.2:p2.axis=signf(distance)
  if simulation.tick%45==0:p2.action='jab'
 action_queue=['','']
 power_queue=[false,false]
 var frozen:bool=simulation.freeze_frames>0
 simulation.step([p1,p2])
 # The laboratory measures the contact; its timeline never runs a camera cut.
 # Resolve confirmed supers immediately so training cannot remain suspended.
 if not simulation.pending_cinematic.is_empty():simulation.resolve_cinematic()
 for i in range(2):actors[i].apply_state(simulation.fighters[i],not frozen)
 for event in simulation.events:
  _event(event)
 _update_training_display()

func _event(event:Dictionary) -> void:
 var type:String=event.get('type','')
 if type=='move_started' and int(event.get('fighter',0))==0:
  workbench.select_move_id(str(event.get('move','')),false)
  selected=workbench.selected_move()
 if type in ['hit','blocked','guard_break']:
  var defender:int=int(event.get('defender',1))
  var at:Vector2=simulation.fighters[defender].position+Vector2(0,1.2)
  stage.impact(at,type=='blocked')
  var text:String='GUARD BREAK' if type=='guard_break' else 'BLOCK' if type=='blocked' else 'HIT CONFIRMED'
  contact_label.text=text
  notification_time=.65
  history.push_front('F%d  %s  %s' % [simulation.tick,text,str(event.get('move','')).to_upper()])
  if history.size()>3:history.pop_back()
  history_label.text='   /   '.join(history)

func _update_preview() -> void:
 if actors.size()<2:return
 var f:Dictionary=simulation.fighters[0]
 f.move=selected
 f.move_frame=preview_frame
 f.state=selected.phase_at(preview_frame)
 actors[0].preview_move(selected,preview_frame)
 actors[0].position=Vector3(f.position.x,f.position.y,0)
 actors[1].apply_state(simulation.fighters[1],true)
 workbench.update_playhead(preview_frame,selected.phase_at(preview_frame))
 frame_label.text='FRAME %02d / %02d' % [preview_frame,selected.total_frames()-1]
 phase_label.text=selected.phase_at(preview_frame).to_upper()
 phase_label.modulate=_phase_color(selected.phase_at(preview_frame))
 detail_label.text='%s   ·   %d STARTUP / %d ACTIVE / %d RECOVERY   ·   %s' % [selected.display_name,selected.startup,selected.active,selected.recovery,'INVULNERABLE' if selected.is_invulnerable(preview_frame) else 'VULNERABLE']
 tick_label.text='60 Hz  /  %.1f ms per frame' % (1000.0/60.0)
 _refresh_boxes()

func _update_training_display() -> void:
 var f:Dictionary=simulation.fighters[0]
 var current:MoveData=f.move
 var frame:int=f.move_frame
 frame_label.text='FRAME %02d' % maxi(0,frame)
 phase_label.text=str(f.state).to_upper()
 phase_label.modulate=_phase_color(str(f.state))
 tick_label.text='TICK %d   /   HITSTOP %d' % [simulation.tick,simulation.freeze_frames]
 detail_label.text='STUN %d f   ·   COMBO %d   ·   P1 GUARD %d   ·   P1 ENERGY %d' % [f.stun,f.combo,int(f.guard),int(f.energy)]
 if current!=null:workbench.update_playhead(frame,current.phase_at(frame))
 for i in range(2):
  health_bars[i].value=simulation.fighters[i].hp
  guard_bars[i].value=simulation.fighters[i].guard
  energy_bars[i].value=simulation.fighters[i].energy
 _refresh_boxes()

func _refresh_boxes() -> void:
 if stage==null:return
 var hits:Array=[]
 var hurts:Array=[]
 var invulnerable:Array=[]
 for i in range(2):
  hits.append_array(simulation.hitboxes(i))
  hurts.append_array(simulation.hurtboxes(i))
  var fighter:Dictionary=simulation.fighters[i]
  var move:MoveData=fighter.move
  if move!=null and move.is_invulnerable(fighter.move_frame):
   var center:Vector2=fighter.position+Vector2(move.hurtbox_offset.x*fighter.facing,move.hurtbox_offset.y)
   invulnerable.append(Rect2(center-move.hurtbox_size/2,move.hurtbox_size))
 hits.append_array(simulation.projectile_hitboxes())
 stage.draw_boxes(hits,hurts,invulnerable,debug_visible)
 stage.frame_fighters(simulation.fighters)

func _phase_color(phase:String) -> Color:
 if phase=='startup':return Color('#edc16a')
 if phase=='active':return Color('#ff657d')
 if phase=='recovery':return Color('#789fee')
 return Color('#bac8c9')

func _unhandled_key_input(event:InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 var code:int=event.physical_keycode
 if code==KEY_ESCAPE:
  playing=not playing
  workbench.set_playing(playing)
 elif code==KEY_SPACE:
  playing=not playing
  workbench.set_playing(playing)
 elif code==KEY_PERIOD:_step_once()
 elif code==KEY_R:_reset()
 elif code==KEY_B:
  debug_visible=not debug_visible
  _refresh_boxes()
 elif mode=='training':
  var keys:Dictionary={KEY_J:'jab',KEY_K:'cross',KEY_L:'low_kick',KEY_U:'launcher',KEY_SHIFT:'dodge',KEY_O:'burst',KEY_P:'finisher'}
  var p2keys:Dictionary={KEY_1:'jab',KEY_2:'cross',KEY_3:'low_kick',KEY_4:'dodge',KEY_5:'launcher',KEY_6:'burst',KEY_8:'finisher'}
  if keys.has(code):action_queue[0]=keys[code]
  if p2keys.has(code):action_queue[1]=p2keys[code]
  if code==KEY_H:power_queue[0]=true
  if code==KEY_7:power_queue[1]=true

func _capture_later() -> void:
 await get_tree().create_timer(3.0).timeout
 playing=false
 workbench.set_playing(false)
 preview_frame=selected.startup
 _update_preview()
 await RenderingServer.frame_post_draw
 var path:String='/tmp/rift-godot-lab.png'
 var args=OS.get_cmdline_user_args()
 var idx=args.find('--capture')
 if idx>=0 and idx+1<args.size():path=args[idx+1]
 var image=get_viewport().get_texture().get_image()
 image.save_png(path)
 print('CAPTURED ',path)
 if '--quit-after-capture' in args:get_tree().quit()

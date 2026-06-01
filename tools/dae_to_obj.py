import bpy, sys, os

# Like fbx_to_obj.py but for a Mixamo Collada (.dae) that carries an idle
# animation. We pose the armature at a chosen frame (a relaxed standing pose
# from the idle), bake THAT pose into the static mesh, and export OBJ — giving a
# natural-looking static character instead of the stiff T-pose.
argv = sys.argv[sys.argv.index("--") + 1:]
dae_in, obj_out = argv[0], argv[1]
frame = int(argv[2]) if len(argv) > 2 else 1
texdir = os.path.dirname(os.path.abspath(obj_out))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.collada_import(filepath=dae_in)
bpy.context.scene.frame_set(frame)

if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

for obj in [o for o in bpy.data.objects if o.type == 'MESH']:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)   # bakes the posed frame
        except RuntimeError:
            obj.modifiers.remove(m)
    if obj.parent is not None:
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')

for o in list(bpy.data.objects):
    if o.type in {'ARMATURE', 'EMPTY'}:
        bpy.data.objects.remove(o, do_unlink=True)

for img in bpy.data.images:
    if img.has_data and img.size[0] > 0:
        name = img.name if img.name.lower().endswith('.png') else img.name + '.png'
        try:
            img.filepath_raw = os.path.join(texdir, name)
            img.file_format = 'PNG'
            img.save()
            print("SAVED_TEX", name)
        except Exception as e:
            print("TEXFAIL", e)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.obj_export(filepath=obj_out, export_materials=True,
                      path_mode='STRIP', up_axis='Y', forward_axis='NEGATIVE_Z')
print("OBJDONE")

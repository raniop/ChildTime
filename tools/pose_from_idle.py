import bpy, sys, os, re

# Give a T-pose Mixamo FBX the relaxed arms-down idle pose by copying the pose
# from an existing Mixamo idle .dae (same mixamorig skeleton), then baking.
argv = sys.argv[sys.argv.index("--") + 1:]
fbx_in, obj_out, idle_dae = argv[0], argv[1], argv[2]
texdir = os.path.dirname(os.path.abspath(obj_out))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx_in)
char_meshes = [o for o in bpy.data.objects if o.type == 'MESH']
char_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')

before = set(bpy.data.objects)
bpy.ops.wm.collada_import(filepath=idle_dae)
new_objs = [o for o in bpy.data.objects if o not in before]
idle_arm = next(o for o in new_objs if o.type == 'ARMATURE')
for o in [o for o in new_objs if o.type == 'MESH']:
    bpy.data.objects.remove(o, do_unlink=True)

bpy.context.scene.frame_set(1)


def norm(n):
    return re.sub(r'[^a-z0-9]', '', n.lower()).replace('mixamorig', '')


idle_map = {norm(b.name): b for b in idle_arm.pose.bones}
copied = 0
for b in char_arm.pose.bones:
    src = idle_map.get(norm(b.name))
    if src:
        b.rotation_mode = 'QUATERNION'
        b.matrix_basis = src.matrix_basis.copy()
        copied += 1
print("copied bones:", copied)
bpy.context.view_layer.update()

for obj in char_meshes:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError: obj.modifiers.remove(m)
    if obj.parent is not None: bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')

for o in list(bpy.data.objects):
    if o.type in {'ARMATURE', 'EMPTY'}: bpy.data.objects.remove(o, do_unlink=True)

for img in bpy.data.images:
    if img.has_data and img.size[0] > 0:
        name = img.name if img.name.lower().endswith('.png') else img.name + '.png'
        try:
            img.filepath_raw = os.path.join(texdir, name); img.file_format = 'PNG'; img.save()
        except Exception: pass

bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.obj_export(filepath=obj_out, export_materials=True, path_mode='STRIP', up_axis='Y', forward_axis='NEGATIVE_Z')
print("OBJDONE")

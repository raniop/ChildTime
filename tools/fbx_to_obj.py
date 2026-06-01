import bpy, sys, os

# Blender step of the FBX -> .scn pipeline. Imports a Mixamo FBX, bakes the
# armature pose into a static mesh (SceneKit's UsdSkel/skinned support is poor),
# writes embedded textures out as PNG, and exports a plain OBJ.
argv = sys.argv[sys.argv.index("--") + 1:]
fbx_in, obj_out = argv[0], argv[1]
texdir = os.path.dirname(os.path.abspath(obj_out))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx_in)

if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

for obj in [o for o in bpy.data.objects if o.type == 'MESH']:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError:
            obj.modifiers.remove(m)
    if obj.parent is not None:
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')

for o in list(bpy.data.objects):
    if o.type in {'ARMATURE', 'EMPTY'}:
        bpy.data.objects.remove(o, do_unlink=True)

# Save embedded textures as PNG next to the OBJ (path_mode STRIP references them
# by basename, which matches these saved files).
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

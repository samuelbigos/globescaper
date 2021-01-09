# exports each selected object into its own file

import bpy
import os
from os.path import dirname, abspath

# export to blend file location
d = dirname(dirname(bpy.data.filepath))
basedir = d + "\\assets\\tiles"

if not basedir:
    raise Exception("Blend file is not saved")

view_layer = bpy.context.view_layer

bpy.ops.object.select_all(action='DESELECT')

for obj in bpy.context.scene.objects:

    obj.select_set(True)
    
    loc = (obj.location.x, obj.location.y, obj.location.z)
    rot = (obj.rotation_euler.z)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler.z = 0

    # some exporters only use the active object
    view_layer.objects.active = obj

    name = bpy.path.clean_name(obj.name)
    fn = os.path.join(basedir, name)

    print("exporting:", obj.name)     
    bpy.ops.export_scene.obj(filepath=fn + ".obj", 
        use_selection=True,
        use_materials=False,
        use_triangles=True)
        
    obj.rotation_euler.z = rot
    obj.location = loc
        
    obj.select_set(False)
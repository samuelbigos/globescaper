extends MeshInstance


export var NebulaHigh: Color;
export var NebulaLow: Color;


func _ready():
	material_override.set_shader_param("u_nebula_high", NebulaHigh)
	material_override.set_shader_param("u_nebula_low", NebulaLow)

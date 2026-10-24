class_name HuntTargetEntry
extends Resource
## One prey-group entry in a hunter's target list: "hunt things in this
## group". A Resource so Array[HuntTargetEntry] is editable in the
## Inspector the same way Array[LootEntry] is for loot tables.

@export var prey_group: StringName = &""

class_name LootEntry
extends Resource
## One line of a loot table: "chance% chance to drop min..max of item".
## A Resource (not a plain class) so Array[LootEntry] is editable in the
## Inspector as a list of sub-resources.

@export var item: ItemBase
@export var min_amount: int = 1
@export var max_amount: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0
## Drop the rolled amount as that many separate one-each pickups that
## scatter and get magnetised in individually, instead of a single
## combined stack. Nice for chunky drops like a skeleton's bones.
@export var drop_individually: bool = false

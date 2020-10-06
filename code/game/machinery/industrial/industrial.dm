// Base type for machinery that involves semi or fully automated inputs and outputs.
// The machines can input and output reagents using fluid ducts.
// They can also exchange thermal energy with each other by using heat ducts.
// I/O for solid objects could be added later with stuff like conveyer belts or something.

/obj/machinery/industrial
	name = "industrial machine"
	desc = "If you can read me, something is wrong."
	dir = NORTH
	var/reagent_buffer_volume = 60
	// Determines which sides input and output things.
	// Note that the machine can be rotated, and all of the sides will be rotated as well.
	var/list/base_fluid_duct_input_dirs = null
	var/list/base_fluid_duct_output_dirs = null
	var/list/base_heat_duct_dirs = null

/obj/machinery/industrial/initialize()
	if(reagent_buffer_volume)
		create_reagents(reagent_buffer_volume)
	return ..()

// TODO: Better name.
/obj/machinery/industrial/melter
	name = "melter"
	desc = "This exchanges heat with objects placed inside, with the intent to melt the objects and output the resulting liquids."
	base_fluid_duct_output_dirs = list(SOUTH)
	heat_duct_sides = list(SOUTH, EAST, WEST)

// Accepts reagent containers and tries to shove their contents into its fluid duct.
/obj/machinery/industrial/manual_input
	base_fluid_duct_output_dirs = list(SOUTH)

// Similar to above, but fills reagent containers that touch it, using its fluid duct, similar to how sinks work.
/obj/machinery/industrial/manual_output
	base_fluid_duct_input_dirs = list(SOUTH)

// Destroys reagents piped into it.
// Yes, this also destroys the reagent's energy and breaks physics.
/obj/machinery/industrial/reagent_void
	base_fluid_duct_input_dirs = list(SOUTH)

// Zaps certain reagents to split them apart, e.g. (Water > Hydrogen, Oxygen), or (Salt Water > Hydrogen, Chlorine, Sodium Hydroxide).
/obj/machinery/industrial/electrolysis
	base_fluid_duct_input_dirs = list(SOUTH)
	base_fluid_duct_output_dirs = list(EAST, WEST)

/obj/machinery/industrial/proc/push_reagent()

	



// Base type for 'ducts', a simple version of pipes that connect things together.
// They should also have less of a footprint than atmos pipes, due to not processing.
// Inspired by TG ducts, since porting them isn't possible without needing to satisfy a large number of dependencies.
/obj/machinery/duct
	var/connects = null // Bitflag of dirs.
	var/duct_network_type = /datum/duct_network
	var/datum/duct_network/network = null

/obj/machinery/duct/update_icon()
	var/temp_icon = initial(icon_state)
	for(var/D in GLOB.cardinals)
		if(D & connects)
			if(D == NORTH)
				temp_icon += "_n"
			if(D == SOUTH)
				temp_icon += "_s"
			if(D == EAST)
				temp_icon += "_e"
			if(D == WEST)
				temp_icon += "_w"
	icon_state = temp_icon

// Heat ducts are essentially heat pipes, and let different machines exchange thermal energy.
/obj/machinery/duct/heat_duct
	name = "heat duct"
	desc = "A heat pipe. It conducts thermal energy and acts as a means to transfer heat. \
	This one has thermal insulation on the outside, to stop heat from being lost and possibly cooking people alive."
	var/duct_network_type = /datum/duct_network/heat

// Fluid ducts move reagents between machines instantly. Things such as pressure and volume are not simulated for performance/simplicity reasons.
/obj/machinery/duct/fluid_duct
	name = "fluid duct"
	desc = "A form of pipe that allows machines to exchange liquids and gases safely."
	icon = 'icons/obj/ducts/fluid_ducts.dmi'
	icon_state = "nduct"



// Note: This is NOT a straight copypaste of /TG/'s `/datum/ductnet`, but is rather different due to a 
// combination of unmet requirements from the TG version, and dependencies that currently can't be satisfied.
// The upside side is that this can be a bit more flexible and handle things beyond reagents.
// The downside is the lack of COMSIG stuff will probably annoy very specific people.

// Base type that handles things like connections.
/datum/duct_network
	var/list/obj/machinery/duct/ducts = list()

/datum/duct_network/proc/add_duct(obj/machinery/duct/D)
	if(!D || D in ducts)
		return FALSE
	ducts += D
	D.network = src

/datum/duct_network/proc/merge_networks(datum/duct_network/D)
	ducts += D.ducts

	for(var/thing in D.ducts)
		var/obj/machinery/duct/D = thing
		D.network = src
	//destroy_network() // ????
	D.destroy_network()

/datum/duct_network/proc/destroy_network(delete = TRUE)
	for(var/thing in ducts)
		var/obj/machinery/duct/D = thing
		D.network = null
	if(delete)
		qdel(src)

// Subtype which is involved in reagent transfer.
// Transfers reagents from suppliers to demanders instantly.
/datum/duct_network/reagent
	var/list/obj/machinery/industrial/suppliers = list()
	var/list/obj/machinery/industrial/demenders = list()

/datum/duct_network/reagent/destroy_network(delete = TRUE)
	..(delete)

// Subtype which transfers heat between things.
// The result of storing the temperature in the network datum is that it will be very fast to interact with it,
// as opposed to having every heat pipe store its own temperature and conduct heat between pipes.
// That would be more realistic, but also a lot laggier.
// Some weirdness can happen if heat duct networks get changed mid-round and conservation of energy might be violated, but that's not really new to ss13.
/datum/duct_network/heat
	var/temperature = T20C



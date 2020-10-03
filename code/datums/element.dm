#define ELEMENT_PHASE_SOLID		1
#define ELEMENT_PHASE_LIQUID	2
#define ELEMENT_PHASE_GAS		3

#define REAGENT_UNIT_TO_GRAMS	10
#define SHEETS_TO_GRAMS REAGENTS_PER_SHEET * REAGENT_UNIT_TO_GRAMS

// This datum holds information about the physical characteristics of a specific element or material.
// 'Element' is being used loosely and can be used for things that are made from a combination of elements, e.g. water.

GLOBAL_LIST_INIT(all_elements, init_subtypes_assoc(/datum/element))

/datum/element
	// Identity.
	var/symbol = null // Chemical symbol or formula, e.g. "Fe", or "H2O".
	var/name = null // Base name for the element. Used if not overrided by the vars below.
	var/name_as_solid = null // Used in place of the base name while in the solid state, if defined. E.g. "ice".
	var/name_as_liquid = null // Ditto, in the liquid state, e.g. "water".
	var/name_as_gas = null // Ditto, in the gaseous phase, e.g. "steam".
	var/desc = null // Short description about the element, for flavor.

	var/datum/reagent/associated_reagent = null // Path of reagent that this is associated with. Converted into a ref to the reagent singleton on init.
	var/material/associated_material = null // Ditto, for the reagent system.

	// (Simplified) Thermodynamics.
	// Pressure is not taken into account, so no triple point or boiling in space, sorry.
	// If null, the element cannot transition to the corrisponding phase.
	var/melting_point = null // Point which the element turns from a liquid to a solid.
	var/boiling_point = null // Point which the element turns from a liquid to a gas.
	var/thermodynamic_hysteresis = 2 // Used to artificially prevent the element from flickering between two phases.

	var/specific_heat_capacity = null // J/°K. Amount of energy that one gram of the element must absorb or lose to change its temperature by one degree kelvin/celcius.
	var/thermal_conductivity = null // W/(m*K). Higher numbers make heat transfer happen faster.

/datum/element/New()
	generate_names()
	if(associated_reagent)
		var/reagent_id = initial(associated_reagent.id)
		associated_reagent = chemistryProcess.chemical_reagents[reagent_id] // I wish this was SSchemistry.

// Generates names for different states, if no custom names are defined and a base name exists.
/datum/element/proc/generate_names()
	if(!name)
		return
	if(!name_as_solid)
		name_as_solid = "solid [name]"
	if(!name_as_liquid)
		name_as_liquid = "liquid [name]"
	if(!name_as_gas)
		name_as_gas = "[name] gas"

GLOBAL_DATUM_INIT(thermodynamics, /datum/thermodynamics, new)

// This type holds helper functions to calculate simplified thermodynamics, and is GLOB accessible. It holds no state of it's own.
// The physics this code pretends to use is simplified and ignores lots of real world thermodynamics, like heat capacity changing with temperature.

// For the purposes of thermodynamics, we're gonna assume one unit of reagent equals one centiliter, based on ingame human blood volume.
// This means a large beaker holds 1.2L, and thus one reagent unit equals ten grams.
// Based on xenobio metal solidification, we're also gonna assume sheets of a material are made out of 20 reagent units.
// Thus a single sheet of steel has a mass of 200 grams, and a whole stack has 10kg.
/datum/thermodynamics

// Returns how much the temperature changed with the addition or subtraction of thermal energy.
// Actually applying that to the current temperature and making sure it doesn't go below absolute zero is the responsibility of the caller.
/datum/thermodynamics/proc/add_thermal_energy(datum/element/E, grams, joules)
	return joules / (E.specific_heat_capacity * grams)

// Returns how many joules of energy are needed to raise or lower the temperature of an element to a specific point.
// Negative results mean that energy must be removed to achieve the final temperature.
// Q = cmΔT
/datum/thermodynamics/proc/calculate_energy_required(datum/element/E, grams, initial_temperature, final_temperature)
	return E.specific_heat_capacity * grams * (final_temperature - initial_temperature)

// Instantly equalizes the temperature between an arbitrary number of elements presumably inside the same imaginary container.
// Heat conductivity is ignored.
// All input lists must be the same length and the indicies need to match up.
// Mass must be in grams, temperature must be in kelvin.
// tf = (m1 cp1 t1 + m2 cp2 t2 + .... + mn cpn tn) / (m1 cp1 + m2 cp2 + .... + mn cpn)
/datum/thermodynamics/proc/equalize_thermal_energy(list/elements, list/masses, list/temperatures)
	var/left_side = 0
	var/right_side = 0
	for(var/i in 1 to elements.len)
		var/datum/element/E = elements[i]
		var/m = masses[i]
		var/cp = E.specific_heat_capacity
		var/t = temperatures[i]
		left_side += (m * cp * t)
		right_side += (m * cp)
	
	return left_side / right_side

// Fourier's Law of Heat Conduction
// q = kA(ΔT/L)
/*
q = the rate of conduction heat transfer in Btu/hr,

k = thermal conductivity of the material through which thermal conduction is taking place, in Btu/hr-oF-ft,

A = area perpendicular to heat flow, ft2,

ΔT = the temperature difference that is driving the heat transfer, oF,

L = the distance through which conduction heat transfer is taking place, ft.
*/

// q = c*((ΔT*A)/Δx)
/datum/thermodynamics/proc/fouriers_law(datum/element/E, temperature_delta, area_of_surface, depth_of_surface)
	return E.thermal_conductivity * ((temperature_delta * area_of_surface) / depth_of_surface)

// One dimensional variant of the above.
// q = cΔT/dx
/datum/thermodynamics/proc/fouriers_law_1d(datum/element/E, temperature_delta, depth_of_surface)
	return -E.thermal_conductivity * temperature_delta / depth_of_surface

// q = cΔT
/datum/thermodynamics/proc/fouriers_law_wut(datum/element/E, temperature_delta)
	return -E.thermal_conductivity * temperature_delta

/datum/thermodynamics/proc/get_total_heat(datum/element/E, mass, temperature)
	return temperature * mass * E.specific_heat_capacity

// TODO remove this before going live.
/client/verb/test_thermodynamic_equalize()
	var/list/elements = list(new /datum/element/water(), new /datum/element/iron())
	var/masses = list(120 * REAGENT_UNIT_TO_GRAMS, 120 * REAGENT_UNIT_TO_GRAMS)
	var/list/temperatures = list(T20C, 1811)
	to_world(GLOB.thermodynamics.equalize_thermal_energy(elements, masses, temperatures))


// Temprature datum.
// Allows any object that wants to keep track of temperature to do so.
/datum/temperature
	var/datum/holder = null
	var/datum/element/element = null
	var/temperature = T20C // Kelvin.

/datum/temperature/New(datum/new_holder, datum/element/new_element, new_temperature)
	holder = new_holder
	element = new_element
	temperature = new_temperature

/datum/temperature/Destroy()
	element = null
	return ..()

/datum/temperature/proc/add_thermal_energy(joules, grams)
	. = GLOB.thermodynamics.add_thermal_energy(element, grams, joules)

/*
	if (total_moles == 0)
		return 0

	var/heat_capacity = heat_capacity()
	if (thermal_energy < 0)
		if (temperature < TCMB)
			return 0
		var/thermal_energy_limit = -(temperature - TCMB)*heat_capacity	//ensure temperature does not go below TCMB
		thermal_energy = max( thermal_energy, thermal_energy_limit )	//thermal_energy and thermal_energy_limit are negative here.
	temperature += thermal_energy/heat_capacity
	return thermal_energy
*/

// Elements, and "elements".

/datum/element/oxygen
	symbol = "O2"
	name = "oxygen"
	name_as_gas = "oxygen" // So it doesn't show up as oxygen gas.
	associated_reagent = /datum/reagent/oxygen

	melting_point = 54.36
	boiling_point = 90.188
	specific_heat_capacity = 0.918 // ?
	thermal_conductivity = 0.026

/datum/element/hydrogen
	symbol = "H"
	name = "hydrogen"
	name_as_gas = "hydrogen"
	desc = "Hydrogen is the lightest, and most common element in the universe."
	associated_reagent = /datum/reagent/hydrogen

	melting_point = 13.99
	boiling_point = 20.271
//	specific_heat_capacity = 14.30 // ????!
	thermal_conductivity = 0.186

/datum/element/water
	symbol = "H2O"
	name_as_solid = "ice"
	name_as_liquid = "water"
	name_as_gas = "steam"
	desc = "Water is essential to life, and has a very large heat capacity."
	associated_reagent = /datum/reagent/water

	melting_point = T0C
	boiling_point = T20C + 80
	specific_heat_capacity = 4.1868 // One calorie.
	thermal_conductivity = 0.6065

/datum/element/granite
	name = "granite"
	name_as_solid = "granite"
	name_as_liquid = "molten granite"

	melting_point = 1260
	specific_heat_capacity = 0.790

/datum/element/glass
	name = "glass"
	name_as_solid = "glass"
	name_as_liquid = "molten glass"

	melting_point = 1700
	boiling_point = 2630

	specific_heat_capacity = 0.840

/datum/element/iron
	symbol = "Fe"
	name = "iron"
	name_as_solid = "iron"
	name_as_liquid = "molten iron"
	associated_reagent = /datum/reagent/iron

	melting_point = 1811
	boiling_point = 3143
	specific_heat_capacity = 0.412

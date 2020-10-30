SUBSYSTEM_DEF(persistence)
	name = "Persistence"
	init_order = INIT_ORDER_PERSISTENCE
	flags = SS_NO_FIRE
	var/list/tracking_values = list()
	var/list/persistence_datums = list()
	var/list/deserialized_objects = list()
	var/list/most_recent_deserialized_data = null // Used to help debug
	
	// If a coder wants to change a typepath on an object that gets serialized, put both the old and new paths in this list.
	// The deserializer will look in this list if the path being loaded no longer exists, and subsitutes it if a matching one is found.
	// If for some reason you like changing paths super-often, this can be chained as required, the deserializer will keep following the chain 
	// or give up if it can't find a valid path in the end.
	// Example: `"/obj/item/foo" = "/obj/item/bar"`.
	var/list/type_path_migrations = list()

/datum/controller/subsystem/persistence/Initialize(timeofday)
	for(var/thing in subtypesof(/datum/persistent))
		var/datum/persistent/P = new thing
		persistence_datums[thing] = P
		P.Initialize()
	. = ..()

/datum/controller/subsystem/persistence/Shutdown()
	for(var/thing in persistence_datums)
		var/datum/persistent/P = persistence_datums[thing]
		P.Shutdown()

/datum/controller/subsystem/persistence/proc/track_value(var/atom/value, var/track_type)
	var/turf/T = get_turf(value)
	if(!T)
		return

	var/area/A = get_area(T)
	if(!A || (A.flags & AREA_FLAG_IS_NOT_PERSISTENT))
		return

//	if((!T.z in GLOB.using_map.station_levels) || !initialized)
	if(!(T.z in using_map.station_levels))
		return

	if(!tracking_values[track_type])
		tracking_values[track_type] = list()
	tracking_values[track_type] += value

/datum/controller/subsystem/persistence/proc/forget_value(var/atom/value, var/track_type)
	if(tracking_values[track_type])
		tracking_values[track_type] -= value


/datum/controller/subsystem/persistence/proc/show_info(var/mob/user)
	if(!user.client.holder)
		return

	var/list/dat = list("<table width = '100%'>")
	var/can_modify = check_rights(R_ADMIN, 0, user)
	for(var/thing in persistence_datums)
		var/datum/persistent/P = persistence_datums[thing]
		if(P.has_admin_data)
			dat += P.GetAdminSummary(user, can_modify)
	dat += "</table>"
	var/datum/browser/popup = new(user, "admin_persistence", "Persistence Data")
	popup.set_content(jointext(dat, null))
	popup.open()



/datum
	var/persistent_address = null // Used to look up deserialized objects, so object references have a chance to be preserved.

/datum/proc/calculate_persistent_address()
	return sha1(list2params(vars) + num2text(world.time))

/datum/Destroy()
	if(persistent_address)
		SSpersistence.deserialized_objects -= persistent_address
	return ..()

// Copies information required to recreate this object into an associated list.
// The list can be passed to functions that will serialize it into a .json or .sav file.
// You can use getters instead of direct variable reading, if needed.
// When overriding, make sure to call `. = ..()` somewhere inside, so you don't exclude the fundemental variables.
/datum/proc/save_serialized_data()
	SHOULD_CALL_PARENT(TRUE)
	. = list()
	.[NAMEOF(src, type)] = type
	.[NAMEOF(src, persistent_address)] = calculate_persistent_address()

// Applies information from an associative list to this object.
// Generally used when something's getting deserialized.
// You can use setters instead of direct variable assignment, if needed.
// An unfortunate quirk of going with DEFINEs is that the input list MUST be named `_data`, which shouldn't conflict with any existing var names.
/datum/proc/load_deserialized_data(list/_data)
	SHOULD_CALL_PARENT(TRUE)
	persistent_address = _data[NAMEOF(src, persistent_address)]


// Serializes a specific object to a string.
// Use `write_json(json_string, file_path)` to save the string produced by this to disk.
/datum/controller/subsystem/persistence/proc/object_to_json(datum/object, make_pretty = TRUE)
	if(isnull(object))
		return
	var/list/data = object.save_serialized_data()
	var/json_string = json_encode(data)
	if(make_pretty)
		json_string = pretty_json(json_string)
	return json_string

// Deserializes a string and attempts to recreate the object that had made it.
// Returns the resulting object if successful.
// Use `read_json(file_path)` to get the string that this proc needs.
/datum/controller/subsystem/persistence/proc/json_to_object(json_string)
	var/list/data = json_decode(json_string)
	if(!istype(data))
		log_debug("DESERIALIZATION: Supplied json string resulted in no data.")
		return
	return deserialize_list(data)



/datum/controller/subsystem/persistence/proc/deserialize_list(list/data)
	var/object_type = data[NAMEOF(src, type)]
	if(!ispath(text2path(object_type)))
		log_debug("DESERIALIZATION: Object type '[object_type]' does not appear to exist.")
		// Consider adding a method to migrate old paths to new ones in some kind of list?
		return
	
	var/datum/object = new object_type()
	var/address = data[NAMEOF(src, persistent_address)]
	object.load_deserialized_data(data)
	deserialized_objects[address] = object
	most_recent_deserialized_data = data.Copy()
//	process_reference_lookup_queue()
	return object
	

// Writes a json string to disk, storing it permanently.
// This proc will happily overwrite whatever is in the path, so be aware of that.
/datum/controller/subsystem/persistence/proc/write_json(json_string, file_path)
	var/json_file = file(file_path)
	to_file(json_file, json_string)

// Reads a json file from disk, retriving the json string contained inside.
/datum/controller/subsystem/persistence/proc/read_json(file_path)
	if(!fexists(file_path))
		CRASH("Tried to open file '[file_path]', but it does not exist or cannot be accessed.")
	
	var/json_file = file(file_path)
	return file2text(json_file)

// Adds some whitespace to make the json formatting easier for humans to read.
// `json_decode()` ignores it so it's purely for the benefit of humans.
// However it will add a small amount of overhead when something is being saved.
/datum/controller/subsystem/persistence/proc/pretty_json(json_string)
	// Remove existing whitespace, to avoid double pretty-ifying the string if it contains a json string
	// that was already processed by this proc.
	json_string = replacetext(json_string, "\n", "")
	json_string = replacetext(json_string, "\\n", "")
//	json_string = replacetext(json_string, " ", "")

	var/depth = 0 // How much to indent.
	// This is being done as a list in order to reduce repeatitive concatination, which helps preserve BYOND's super secret string tree.
	var/list/new_json_string = list() 
	for(var/i = 1 to length(json_string))
		var/char = copytext(json_string, i, i+1)
		switch(char)
			if("{", "\[")
				depth++
				new_json_string += "[char]\n[indent(depth)]"
			if("}", "\]")
				depth--
				new_json_string += "\n[indent(depth)][char]"
			if(",")
				new_json_string += "[char]\n[indent(depth)]"
			else
				new_json_string += char
	return new_json_string.Join()

// Used for above proc.
/datum/controller/subsystem/persistence/proc/indent(amount)
	if(amount <= 0)
		return null
	for(var/i = 1 to amount)
		. += "    " // Four spaces.

// Returns a duplicate of a serializable object, without writing to disk.
/datum/controller/subsystem/persistence/proc/clone_object(datum/object)
	return json_to_object(object_to_json(object, FALSE))

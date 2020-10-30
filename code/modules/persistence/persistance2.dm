/*
Serialization, Electric Boogaloo

Biggest difference between the old method and this new method is that the process of saving/loading 
variables to and from lists is now more 'hands on', by which I mean that objects will read/write those 
lists inside a specific function, instead of mostly relying on a list of variable names on the object itself.

This has the obvious downside of requiring some more work to make an object persistable, 
but the upside is having absolute control on how an object gets saved or loaded, which 
means being able to handle more kinds of variable types, such as object references, 
nested or otherwise, without the risk of infinite loops (if done right).

This also means that objects that are loaded can use setter procs to write the data 
to the object, instead of being forced to directly assign the value, resulting in 
less confused objects. The same is true for objects being saved being able to use getters.

Serializing References
Saving, and loading refs are a tricky business. On the saving side, blindly following references 
will easily result in infinite loops. For loading, seperate objects which had a reference to 
a single object can end up having duplicate objects instead.

To solve this problem, a distinction is made between saving objects themselves, and saving references.

Saving a nested object works pretty much the same as you would expect, with one assoc. list holding 
another inside. This should only be done for objects which directly contain the other object. For 
example, a bag which holds a flashlight, which itself holds a device cell. Thus, a good rule of thumb is 
that things that were in an object's `contents` list should be serialized as a nested object. Some other 
objects are conceptually contained by another object, such as reagent datums being contained by the 
object which holds them. These should also be stored as nested objects. In BYOND, it is impossible for 
an object to be in two places at once, in terms the `loc` variable. Serialize with that idea in mind.

The other kind of object reference involves being connected to another object, but not being contained by 
the object. Using the first method here would risk getting trapped in an infinite loop when saving, 
and creating duplicate objects upon loading. There are two ways to avoid that and still be able to have 
a connection between different objects.

First method is to not try to save the reference, but instead save something that can be used later on 
to find the object when deserialized. This is recommended for references to singleton objects, such as 
the species datums, or material datums. An example would be saving the material's name, and then 
looking up an instance of that material inside of `load_deserialized_data()`. This is also recommended for connecting 
to objects that are 'outside' of the objects in question.

Second method is to store a new thing called a `persistent_address`, which is a hash that is computed 
using the same data that is used to deserialize that object, plus a few other things (so cloning doesn't 
create duplicate `persistent_address`es). A hash of the object isn't useful on it's own, but it can be
used to obtain an actual reference to that object, assuming that it was also deserialized. It is 
recommended to use this for object references that exist as part of a larger object, thus guaranteeing 
that both objects would have been deserialized. Otherwise, this method should be used for references 
that won't break the object if the game can't find the other object.


Serialization Process
Saving is generally done in these steps.
 * The game calls `object_to_json(object_reference)`.
 * The function scans the object it was fed, and returns an associative list, using `object_reference.save_serialized_data()`.
   * This can repeat for nested objects. Inner objects will be contained inside their own associative list.
   * References to other objects that aren't nested are saved as persistent addresses.
 * That associative list is turned into a string of json, and `object_to_json()` is finished.
 * Now `write_json(json_string, file_path)` is called, which writes the string onto a file on disk, for permanent storage.

Deserialization Process
Loading almost works like saving in reverse.
 * The game calls `read_json(file_path)`, and reads the file, returning the json file in string form.
 * The json string that was loaded is turned into an associative list, with `json_to_object().
 * A 'bare' object is instantiated, then the information that it had in a previous life is written to it with `object_reference.load_deserialized_data(list/data)`
   * This is repeated as needed for nested objects.
   * Object references that were saved as persistent_addresses are added to a queue, to be processed after the whole object is deserialized.
 * The persistent addresses queue is processed. Hashes are looked up in a global list that is populated by serialized objects.

*/







// General serialization service.
// Exists to organize the code and process reference lookups.
/datum/serialization
	var/list/reference_lookup_queue = list()

/datum/serialization/proc/queue_reference_lookup(datum/object, variable_name, target_address)
	reference_lookup_queue.len++
	reference_lookup_queue[reference_lookup_queue.len] = list("object" = object, "variable_name" = variable_name, "target_address" = target_address)

// Similar to above but returns a list of object references.
//datum/serialization/proc/queue_reference_list_lookup(list/L, list_name)
//	reference_lookup_queue.len++
//	for(var/thing in L)
//
//	reference_lookup_queue[reference_lookup_queue.len] = list("object" = object, "variable_name" = variable_name, "target_address" = target_address)


/datum/serialization/proc/process_reference_lookup_queue()
	if(!LAZYLEN(reference_lookup_queue))
		return
	for(var/i = 1 to reference_lookup_queue)
		var/list/ticket = reference_lookup_queue[i]
		var/datum/object = ticket["object"]

		if(!object || QDELETED(object))
			continue
		
		var/datum/target_object = GLOB.deserialized_objects[ticket["target_address"]]
		if(!target_object || QDELETED(target_object))
			continue
		
		object.vars[ticket["variable_name"]] = target_object
		ticket["object"] = null
	
	reference_lookup_queue.Cut()






// Compares two serializable objects, and returns whether or not they are equivalent.
// Equivalence is determined if both objects produced the same data when serialized.
// An exception is `persistent_address`, as two seperate objects will have different values for that.
/datum/serialization/proc/compare_objects(datum/A, datum/B)
	var/A_data = A.save_serialized_data()
	var/B_data = B.save_serialized_data()
	for(var/key in A_data)
		if(key == NAMEOF(src, persistent_address))
			continue
		if(A_data[key] != B_data[key])
			return FALSE
	return TRUE





/*

// Reads and deserializes a .json file into the correct `/datum/persistent_record` instance.
/datum/persistent_directory/proc/read_json(file_path)
	if(!fexists(file_path))
		CRASH("Tried to open file '[file_path]', but it does not exist or cannot be accessed.")
	
	var/list/data = json_decode(file2text(file_path))
	if(!istype(data))
		return
	var/record_type = data[NAMEOF(src, type)]
	if(!ispath(text2path(record_type)))
		log_debug("Object type '[record_type]' does not appear to exists.")
		return
	var/datum/persistent_record/R = new record_type()
	R.from_list(data)
	log_world("Deserialized [file_path].")
	return R

// Writes a `/datum/persistent_record` to disk as a .json file. Note that this WILL overwrite existing files if the path is the same.
/datum/persistent_directory/proc/write_json(file_path, datum/persistent_record/R, make_pretty = TRUE)
	if(!R)
		return
	var/json_file = file(file_path)

	var/list/data = R.to_list()
	var/json_string = json_encode(data)
	if(make_pretty)
		json_string = pretty_json(json_string)
	to_file(json_file, json_string)
	log_world("Serialized [file_path].")
*/
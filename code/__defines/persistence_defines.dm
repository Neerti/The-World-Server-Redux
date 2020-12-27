// Note: These MUST end with a trailing slash `/`.
#define PERSISTENT_PHOTO_DIRECTORY "data/persistent/images/photos/"
#define PERSISTENT_RECORD_IMAGE_DIRECTORY "data/persistent/images/records/"

// Saves a 'simple' variable, such as a string, number, list, or assocative list.
// Intended to be used inside of an overrided 'save_serialized_data()` proc.
// `NAMEOF()` makes it so compilation fails if the variable name stops existing instead of silently breaking persistence.
// This macro exists to protect from copypasta errors as a result of typing .[NAMEOF(src, the_var_name)] = the_var_name repeatively.
#define SERIALIZE_VAR(X) .[NAMEOF(src, ##X)] = ##X

// Saves an object variable, instead of saving it as an assoc. list.
// In most cases you probably want `SERIALIZE_OBJECT_LIST()` for stuff like object contents, 
// which generally covers most nested objects already without one object shared among others becoming many objects belonging to each object.
// Also helps avoid infinite loops by having two objects linked to each other and having the serializer try to follow both objects back and forth.
// Using contents should be enough.
#define SERIALIZE_OBJECT(X)\
var/datum/D = ##X;\
.[NAMEOF(src, ##X)] = D.save_serialized_data();


// Loads a 'simple' variable, such as a string, number, list, or assocative list.
// Intended to be used inside of an overrided `load_deserialized_data()` proc.
// Made for the same purpose of the above macro, but for loading instead of saving.
#define DESERIALIZE_VAR(X) X = _data[NAMEOF(src, ##X)]

// Saves a regular list of items as a serialized object, instead of merely an assoc list.
// Intended to be used inside of an overrided `save_serialized_data()` proc.
#define SERIALIZE_OBJECT_LIST(X)\
var/list/things = list();\
things.len = X.len;\
var/i = 0;\
for(var/thing in X)\
{\
	var/datum/D = thing;\
	things[++i] = D.save_serialized_data();\
}\
.[NAMEOF(src, ##X)] = things

#define DESERIALIZE_OBJECT_LIST(LIST)\
LIST.Cut();\
for(var/list/L in _data[NAMEOF(src, ##LIST)])\
{\
	var/datum/D = SSpersistence.deserialize_list(L);\
	LIST += D;\
}


#define SERIALIZE(PATH)\
##PATH/save_serialized_data()\
{\
	. = ..();\
}

#define DESERIALIZE(PATH)\
##PATH/load_deserialized_data(list/_data);\
	..();


/*
{\
	..();\
}
*/

/*
load_deserialized_data(list/_data)
	..()
*/
/*
	attachments.Cut()
	for(var/list/L in _data[NAMEOF(src, attachments)])
		var/datum/D = SSpersistence.deserialize_list(L)
		attachments += D
*/

/*
	var/list/things = list()
	for(var/thing in .[NAMEOF(src, attachments)])
		var/datum/D = thing
		var/json_string = SSpersistence.object_to_json(D)
		things += json_string
	.[NAMEOF(src, attachments)] = things
*/

/*
#define GLOBAL_LIST_BOILERPLATE(LIST_NAME, PATH)\
var/global/list/##LIST_NAME = list();\
##PATH/initialize(mapload, ...)\
	{\
	##LIST_NAME += src;\
	return ..();\
	}\
##PATH/Destroy(force, ...)\
	{\
	##LIST_NAME -= src;\
	return ..();\
	}\
*/

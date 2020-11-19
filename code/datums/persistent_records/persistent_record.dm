// Simple datum that gets saved to disk individually.
// Generally managed by some other object.
/datum/persistent_record
	var/name = "Unnamed Case"
	var/desc = null
	var/unique_id = null // Used for serialization and for distinguishing between things with similar names.
	var/creator_name = null
	var/creator_ckey = null
	var/creator_uid = null
	var/list/logs = list()
	var/list/attachments = list()

/datum/persistent_record/save_serialized_data()
	. = ..()
	SERIALIZE_VAR(name)
	SERIALIZE_VAR(desc)
	SERIALIZE_VAR(unique_id)
	SERIALIZE_VAR(logs)
	SERIALIZE_VAR(creator_name)
	SERIALIZE_VAR(creator_ckey)
	SERIALIZE_VAR(creator_uid)
	SERIALIZE_OBJECT_LIST(attachments)

/datum/persistent_record/load_deserialized_data(list/_data)
	..()
	DESERIALIZE_VAR(name)
	DESERIALIZE_VAR(desc)
	DESERIALIZE_VAR(unique_id)
	DESERIALIZE_VAR(logs)
	DESERIALIZE_VAR(creator_name)
	DESERIALIZE_VAR(creator_ckey)
	DESERIALIZE_VAR(creator_uid)
	DESERIALIZE_OBJECT_LIST(attachments)

// Called when a new record is made, that wasn't the result of deserialization.
/datum/persistent_record/proc/on_new_record(mob/living/user)
	unique_id = "[game_id]-[++GLOB.persistent_record_incrementer]"
	creator_name = user.name
	creator_ckey = ckey(user.key)
	creator_uid = user.GetIdCard()?.unique_ID
	if(!creator_uid) // Just in case.
		creator_uid = user?.mind?.prefs.unique_id
	add_record_log("Created record.")

// Appends the ingame logs for this record.
/datum/persistent_record/proc/add_record_log(line)
	logs += "[stationdate2text()] [get_game_hour()]:[get_game_minute()]:[get_game_second()] - [line]"

/datum/persistent_record/proc/display_html(mob/living/user, admin_view = FALSE)
	. = list()
	. += "<h2>[name]</h2>"
	. += "ID: [unique_id]<br>"
	. += "[desc]"
	
	. += "<hr>"
	. += "<h2>Attachments</h2>"
	for(var/thing in attachments)
		var/datum/record_attachment/A = thing
		. += href(src, list("view_attachment" = attachments.Find(A)), A.title)
	
	. += "<hr>"
	. += "<h2>Logs</h2>"
	for(var/line in logs)
		. += " - [line]<br>"

// A lightweight datum that gets held by persistent records.
// Can represent things ranging from transcripts to photos (TODO).
/datum/record_attachment
	var/title = null
	var/content = null
	var/image_id = null // If set, a persistent image will be loaded and shown to anyone viewing this record.
	var/uploader_name = null
	var/uploader_ckey = null
	var/uploader_uid = null

/datum/record_attachment/proc/display_html(mob/living/user, admin_view = FALSE)
	. = list()
	. += "<h3>[title]</h3>"
	. += "[content]<br>"
	if(uploader_name)
		. += "<i>Uploaded by <b>[uploader_name]</b>.</i>"
	if(admin_view && uploader_ckey)
		. += " (Ckey: [uploader_ckey])"

/datum/record_attachment/save_serialized_data()
	. = ..()
	.[NAMEOF(src, title)] = title
	.[NAMEOF(src, content)] = content
	SERIALIZE_VAR(image_id)
	.[NAMEOF(src, uploader_name)] = uploader_name
	SERIALIZE_VAR(uploader_ckey)
	SERIALIZE_VAR(uploader_uid)

/datum/record_attachment/load_deserialized_data(list/_data)
	..()
	title = _data[NAMEOF(src, title)]
	content = _data[NAMEOF(src, content)]
	DESERIALIZE_VAR(image_id)
	uploader_name = _data[NAMEOF(src, uploader_name)]
	uploader_ckey = _data[NAMEOF(src, uploader_ckey)]
	DESERIALIZE_VAR(uploader_uid)
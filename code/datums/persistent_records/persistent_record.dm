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
// Can represent things ranging from transcripts to photos.
/datum/record_attachment
	var/title = null			// The 'name' of the attachment.
	var/content = null			// The 'body' of the attachment, cannot be changed, so it remains authoritative.
	var/comment = null			// Comments below the 'body', in a seperate area, used to give context or otherwise add onto an attachment.
	var/image_id = null			// If set, a persistent image will be loaded and shown to anyone viewing this record.
	var/icon/image = null		// If above var was set, holds the persisted image.
	var/uploader_name = null	// In-game character name of the uploader.
	var/uploader_ckey = null	// Holds which player uploaded it, only visible to admins.
	var/uploader_uid = null		// UID of the uploader, used for authentication.

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
	SERIALIZE_VAR(title)
	SERIALIZE_VAR(content)
	SERIALIZE_VAR(comment)
	if(image && !image_id) // If it has an image ID already, it means it was saved previously.
		image_id = "[game_id]-[md5(world.time)]"
		SSpersistence.save_image(image, image_id, PERSISTENT_RECORD_IMAGE_DIRECTORY)
	SERIALIZE_VAR(image_id)
	SERIALIZE_VAR(uploader_name)
	SERIALIZE_VAR(uploader_ckey)
	SERIALIZE_VAR(uploader_uid)

/datum/record_attachment/load_deserialized_data(list/_data)
	..()
	DESERIALIZE_VAR(title)
	DESERIALIZE_VAR(content)
	DESERIALIZE_VAR(comment)
	DESERIALIZE_VAR(image_id)
	if(image_id)
		image = SSpersistence.load_image(image_id, PERSISTENT_RECORD_IMAGE_DIRECTORY)
	DESERIALIZE_VAR(uploader_name)
	DESERIALIZE_VAR(uploader_ckey)
	DESERIALIZE_VAR(uploader_uid)
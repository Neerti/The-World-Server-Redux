// Displays `datum/persistent_record`s in an interactive way.
// This is used instead of just having the viewing/interaction logic be on a computer console or something so it can also
// be viewed using admin verbs, in-case a griffon starts throwing junk into one of the persistent record directories or something.

/datum/managed_browser/persistent_record_viewer
	base_browser_id = "persistent_record_viewer"
	title = "Generic Record Viewer"
	size_x = 480
	size_y = 680
	var/datum/persistent_record/loaded_record = null // Current record being viewed, if any.
	var/loaded_record_file_path = null // Where that current record exists on disk.
	
	var/datum/record_attachment/opened_attachment = null
	
	var/datum/persistent_directory/directory = null // Helper object that helps make finding files easier.
	var/directory_type = null // Type to instantiate for above ref.

	var/persistent_record_type = null // Lets users see the records without tightly coupling to this object.

	var/admin_view = FALSE // If true, can see ckeys and can do things like deleting.


/datum/managed_browser/persistent_record_viewer/New()
	directory = new directory_type()
	return ..()

/datum/managed_browser/persistent_record_viewer/Destroy()
	if(loaded_record)
		close_record()
	QDEL_NULL(directory)
	return ..()


// File I/O.

// Sets the viewer to not view a specific record.
// Will automatically save the currently loaded record if one is present.
/datum/managed_browser/persistent_record_viewer/proc/close_record()
	if(loaded_record && loaded_record_file_path)
		save_record(loaded_record_file_path)
	opened_attachment = null
	QDEL_NULL(loaded_record)
	loaded_record_file_path = null

// Opens a .json file, deserializes it, and loads the resulting object.
/datum/managed_browser/persistent_record_viewer/proc/load_record(file_path)
	if(!file_path)
		return
	
	var/datum/persistent_record/R = SSpersistence.json_to_object(SSpersistence.read_json(file_path))
	if(!istype(R))
		return
	
	loaded_record = R
	loaded_record_file_path = file_path // This is make it easy to save to the same file path.
	return R

// Saves the loaded record object, serializing it into a .json file that gets written to the inputted file path.
// This WILL overwrite anything in the same path without asking.
/datum/managed_browser/persistent_record_viewer/proc/save_record(file_path)
	if(!istype(loaded_record))
		return
	if(!file_path)
		return
	var/json_string = SSpersistence.object_to_json(loaded_record)
	SSpersistence.write_json(json_string, file_path)

// Creates a fresh new record object. Note that the new record isn't immediately saved.
/datum/managed_browser/persistent_record_viewer/proc/make_new_record(mob/living/user)
	var/datum/persistent_record/R = new persistent_record_type()
	R.on_new_record(user)
	loaded_record = R

// Defines the default file path for new records. Make sure this results in a unique path or it will overwrite things.
// It's generally a bad idea to let players be able to directly name the file that's saved to disk.
/datum/managed_browser/persistent_record_viewer/proc/default_new_record_filepath(datum/persistent_record/R)
	return "[directory.actual_directory][R.unique_id].json"

// Returns a list of strings containing all file paths inside the directory that the persistent records sit inside of.
/datum/managed_browser/persistent_record_viewer/proc/get_all_records()
	return directory.get_all_files(directory.actual_directory)

// Allows a user to choose a record to load safely, I.E. limited to a specific directory and its contents (recursively).
// Out Of Character stuff like the full filepaths and the file extension are hidden from the user.
// e.g. `data/persistent/records/police/b9M-dlAU_2.json` is what gets returned but the user only would see `/b9M-dlAU_2`.
// Not sure if BYOND will follow symlinks or not but if the server host decides to symlink to somewhere important that this proc can see, that's on them.
/datum/managed_browser/persistent_record_viewer/proc/choose_record(mob/living/user)
	var/file_path = directory.choose_file(user, directory.actual_directory)
	if(!file_path)
		return

	load_record(file_path)


/datum/managed_browser/persistent_record_viewer/get_html()
	var/list/dat = list()
	dat += display_file_text()
	dat += "<hr>"

	if(opened_attachment && loaded_record)
		dat += href(src, list("close_attachment" = 1), "Close Attachment")
		// TODO: Some kind of 'present' button to be used during trials?
		dat += display_attachment(loaded_record, opened_attachment, my_client)
	else if(loaded_record)
		dat += display_base_fields(loaded_record)
		dat += display_subtype_fields(loaded_record)
		dat += display_record_attachments(loaded_record)
		dat += display_logs(loaded_record)
	else
		dat += "<b>No record currently loaded. Use the buttons above to open or create a record.</b>"


	return dat.Join()



// Display.
// Makes the buttons and such for saving/loading/etc records.
// Shown on the top of the window, acts as a menu bar.
/datum/managed_browser/persistent_record_viewer/proc/display_file_text()
	. = list()
	. += "<center>"
	. += href(src, list("choose_record" = 1), "Open Record")
	if(loaded_record)
		. += href(src, list("save_record" = 1), "Save Record")
	else
		. += " <b>Save Record</b> "
	. += href(src, list("close_record" = 1), "Close Record")
	. += href(src, list("new_record" = 1), "New Record")
	. += "</center>"

// Makes the output for the base part of the record, that all records have, e.g. the name/desc/ID/etc.
// Subtypes with more fields can
/datum/managed_browser/persistent_record_viewer/proc/display_base_fields(datum/persistent_record/R)
	. = list()
	. += "<h2>[R.name]</h2>"
	. += href(src, list("edit_name" = 1), "Edit Name")
	. += "ID: [R.unique_id]<br>"
	. += "<i>Created by <b>[R.creator_name]</b>.</i><br>"
	if(admin_view)
		. += span("notice", "Player Ckey: [R.creator_ckey]")
		. += "<br>"
	. += "[R.desc]<br>"
	. += href(src, list("edit_desc" = 1), "Edit Description")
	. += "<br>"

// Override for subtypes that have more fields, e.g. the court cases.
/datum/managed_browser/persistent_record_viewer/proc/display_subtype_fields(datum/persistent_record/R)

/datum/managed_browser/persistent_record_viewer/proc/display_record_attachments(datum/persistent_record/R)
	. = list()
	. += "<hr>"
	. += "<h2>Attachments</h2>"
	if(!admin_view) // The one thing admin verb can't do, due to not being physical.
		. += "<i>To upload attachments, scan an object with the machine you are using to access this.</i><br>"
	for(var/thing in R.attachments)
		var/datum/record_attachment/A = thing
		. += href(src, list("open_attachment" = R.attachments.Find(A)), A.title)
		. += "<br>"


/datum/managed_browser/persistent_record_viewer/proc/display_attachment(datum/persistent_record/R, datum/record_attachment/A, client/C)
	. = list()
	. += "<h3>[A.title]</h3>"
	. += "[A.content]<br>"
	. += "<hr>"
	. += "<i>Uploaded by <b>[A.uploader_name]</b>.</i>"
	if(admin_view)
		. += " (Ckey: [A.uploader_ckey])<br>"
	if(can_delete_attachment(R, A, C))
		. += "<br>"
		. += href(src, list("delete_attachment" = R.attachments.Find(A)), "Delete Attachment")

/datum/managed_browser/persistent_record_viewer/proc/display_logs(datum/persistent_record/R)
	. = list()
	. += "<hr>"
	. += "<h2>Logs</h2>"
	for(var/line in R.logs) // TODO: Truncate superlong log lines and add a button that prints the full log to the chatlog.
		. += " - [line]<br>"

/datum/managed_browser/persistent_record_viewer/proc/can_delete_record(datum/persistent_record/R, client/C)
	var/obj/item/weapon/card/id/ID = C.mob.GetIdCard()
	return ID?.unique_ID == R.creator_uid || admin_view

/datum/managed_browser/persistent_record_viewer/proc/can_delete_attachment(datum/persistent_record/R, datum/record_attachment/A, client/C)
	var/obj/item/weapon/card/id/ID = C.mob.GetIdCard()
	return ID?.unique_ID == A.uploader_uid || ID?.unique_ID == R.creator_uid || admin_view


// Interactivity.

/datum/managed_browser/persistent_record_viewer/Topic(href, href_list)
	if(..())
		return
	
	var/mob/living/user = usr
	if(!istype(user))
		return

	if(href_list["choose_record"])
		choose_record(user)
	
	if(href_list["new_record"])
		make_new_record(user)
	
	if(href_list["close_record"])
		loaded_record = null

	if(href_list["save_record"])
		if(!loaded_record)
			return
		var/record_file_path = null
		if(loaded_record_file_path)
			record_file_path = loaded_record_file_path
		else
			record_file_path = default_new_record_filepath(loaded_record)
		save_record(record_file_path)
	
	if(href_list["open_attachment"])
		if(!loaded_record)
			return
		var/index = text2num(href_list["open_attachment"])
		var/datum/record_attachment/A = LAZYACCESS(loaded_record.attachments, index)
		if(A)
			opened_attachment = A
	
	if(href_list["close_attachment"])
		opened_attachment = null
	
	if(href_list["edit_name"])
		if(!loaded_record)
			return
		var/new_name = sanitize(input(user, "Write the new name here.", "New Name", loaded_record.name) as null|text)
		if(!(new_name))
			return
		loaded_record.add_record_log("[user.name] renamed the file '[loaded_record.name]' to '[new_name]'.")
		loaded_record.name = new_name
	
	if(href_list["edit_desc"])
		if(!loaded_record)
			return
		var/new_desc = sanitize(input(user, "Write the description here.", "New Description", loaded_record.desc) as null|message)
		if(!(new_desc))
			return
		loaded_record.add_record_log("[user.name] changed the description from '[loaded_record.desc]' to '[new_desc]'.")
		loaded_record.name = new_desc
	
	show_to_user(user) // To refresh the window and assign client if needed.


// Subtypes.
/datum/managed_browser/persistent_record_viewer/police_case
	base_browser_id = "persistent_record_viewer-police"
	title = "Police Case Record Viewer"
	directory_type = /datum/persistent_directory/police
	persistent_record_type = /datum/persistent_record/police_case

/*
/obj/machinery/computer/persistent_record/proc/build_window(mob/living/user)
	. = list()
	. += display_file_text()
	. += "<hr>"
	if(loaded_record)
		. += display_record(user, loaded_record)

/obj/machinery/computer/persistent_record/proc/display_record(mob/living/user, datum/persistent_record/R)
	return R.display_html(user)
*/
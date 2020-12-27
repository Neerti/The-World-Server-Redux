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
	var/collapsed_attachments_list = TRUE
	var/collapsed_log_list = TRUE
	
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
	loaded_record_file_path = file_path // This makes it easy to save to the same file path.
	collapsed_attachments_list = TRUE
	collapsed_log_list = TRUE
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
	loaded_record_file_path = default_new_record_filepath(R)

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

#define SEARCH_METHOD_ID		"by unique ID"
#define SEARCH_METHOD_NAME		"by name"
#define SEARCH_METHOD_DESC		"by content"
#define SEARCH_METHOD_CREATOR	"by creator"

// Prompts the user to enter a search method and then a string to search for.
/datum/managed_browser/persistent_record_viewer/proc/search_query(mob/user)
	var/list/options = list(SEARCH_METHOD_ID, SEARCH_METHOD_NAME, SEARCH_METHOD_DESC, SEARCH_METHOD_CREATOR)
	
	var/search_method = input(user, "Select search method.", "Record Search", SEARCH_METHOD_ID) as null|anything in options
	if(isnull(search_method))
		return
	
	var/search_target = input(user, "Enter search term.", "Searching [search_method].") as null|text
	if(isnull(search_target))
		return
	
	var/list/results = search_records(search_target, search_method)
	if(!LAZYLEN(results))
		to_chat(user, SPAN_WARNING("Searching [search_method] for '[search_target]' produced no results."))
		return
	
	var/list/cleaned_results = directory.clean_file_paths(results)
	var/choice = input(user, "Choose a file.", "File Selection") as null|anything in cleaned_results
	if(isnull(choice))
		return
	var/index_chosen = cleaned_results.Find(choice)
	load_record(results[index_chosen])


// Returns a list of records that match whatever was searched for.
/datum/managed_browser/persistent_record_viewer/proc/search_records(search_target, search_method)
	. = list()
	var/list/all_record_filepaths = get_all_records()
	for(var/file_path in all_record_filepaths)
		var/datum/persistent_record/R = SSpersistence.json_to_object(SSpersistence.read_json(file_path))
		
		if(!istype(R))
			continue
		
		switch(search_method)
			if(SEARCH_METHOD_NAME)
				if(findtext(R.name, search_target))
					. += file_path
			
			if(SEARCH_METHOD_DESC)
				var/list/content = list(R.desc)
				for(var/thing in R.attachments)
					content += thing
				for(var/string in content)
					if(findtext(string, search_target))
						. += file_path
						break
			
			if(SEARCH_METHOD_CREATOR)
				if(findtext(R.creator_name, search_target))
					. += file_path
			
			if(SEARCH_METHOD_ID)
				if(findtext(R.unique_id, search_target))
					. += file_path
		CHECK_TICK

#undef SEARCH_METHOD_ID
#undef SEARCH_METHOD_NAME
#undef SEARCH_METHOD_DESC
#undef SEARCH_METHOD_CREATOR

// Display.

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

// Makes the buttons and such for saving/loading/etc records.
// Shown on the top of the window, acts as a menu bar.
/datum/managed_browser/persistent_record_viewer/proc/display_file_text()
	. = list()
	. += "<center>"
	. += href(src, list("choose_record" = 1), "Open Record")
	. += href(src, list("search_record" = 1), "Search for Record")
	if(loaded_record)
		. += href(src, list("save_record" = 1), "Save Record")
	else
		. += " <b>Save Record</b> "
	. += "<br>"
	. += href(src, list("close_record" = 1), "Close Record")
	. += href(src, list("new_record" = 1), "New Record")
	. += "</center>"

// Makes the output for the base part of the record, that all records have, e.g. the name/desc/ID/etc.
// Subtypes with more fields can
/datum/managed_browser/persistent_record_viewer/proc/display_base_fields(datum/persistent_record/R)
	. = list()
	. += "<h2>[R.name]</h2>"
	. += href(src, list("edit_name" = 1), "Edit Name")
	. += "<br>"
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
	
	if(!LAZYLEN(R.attachments))
		. += "No attachments on this file."

	else if(collapsed_attachments_list)
		. += href(src, list("toggle_collapsed_attachments_list" = 1), "> ([LAZYLEN(R.attachments)])")
		. += "<br>"
	
	else
		. += href(src, list("toggle_collapsed_attachments_list" = 1), "V")
		. += "<br>"
		for(var/thing in R.attachments)
			var/datum/record_attachment/A = thing
			. += " - "
			. += href(src, list("open_attachment" = R.attachments.Find(A)), A.title)
			. += "<br>"


/datum/managed_browser/persistent_record_viewer/proc/display_attachment(datum/persistent_record/R, datum/record_attachment/A, client/C)
	. = list()
	. += "<h3>[A.title]</h3>"
	if(A.image)
		var/cache_filename = "persistent_record_[REF(A)].png"
		C << browse_rsc(A.image, cache_filename)
	//	. += "<img src='[cache_filename]' width='[64*photo_size]' style='-ms-interpolation-mode:nearest-neighbor' />"
		. += "<img src='[cache_filename]' width='200%' style='-ms-interpolation-mode:nearest-neighbor'>"
		. += "<br>"
	. += "[A.content]<br>"
	. += "<hr>"
	. += "<i>Uploaded by <b>[A.uploader_name]</b>.</i>"
	if(A.comment)
		. += "Comment: [A.comment]<br>"
	. += href(src, list("edit_comment" = R.attachments.Find(A)), "Edit Comment")
	if(admin_view)
		. += " (Ckey: [A.uploader_ckey])<br>"
	if(can_delete_attachment(R, A, C))
		. += "<br>"
		. += href(src, list("delete_attachment" = R.attachments.Find(A)), "Delete Attachment")

/datum/managed_browser/persistent_record_viewer/proc/display_logs(datum/persistent_record/R)
	. = list()
	. += "<hr>"
	. += "<h2>Logs</h2>"

	if(!LAZYLEN(R.logs))
		. += "No logs on this file."
	
	else if(collapsed_log_list)
		. += href(src, list("toggle_collapsed_log_list" = 1), "> ([LAZYLEN(R.logs)])")
		. += "<br>"
	
	else
		. += href(src, list("toggle_collapsed_log_list" = 1), "V")
		. += "<br>"
		var/const/line_length_limit = 128
		for(var/line in R.logs)
			// Truncate really long lines from the main window. Instead, a button shows up that shows the whole thing in the chatlog.
			if(length(line) > line_length_limit)
				. += " - [copytext(line, 1, line_length_limit)]... ([length(line)])"
				. += href(src, list("show_log_line" = R.logs.Find(line)), "Show Full Log")
				. += "<br>"
			else
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

	if(href_list["close"])
		return

	if(href_list["choose_record"])
		choose_record(user)
	
	if(href_list["search_record"])
		search_query(user)
	
	if(href_list["new_record"])
		make_new_record(user)
	
	if(href_list["close_record"])
		close_record()

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
		loaded_record.desc = new_desc
	
	if(href_list["show_log_line"])
		var/index = text2num(href_list["show_log_line"])
		var/full_line = LAZYACCESS(loaded_record?.logs, index)
		if(full_line)
			to_chat(user, full_line)
	
	if(href_list["toggle_collapsed_log_list"])
		collapsed_log_list = !collapsed_log_list
	
	if(href_list["toggle_collapsed_attachments_list"])
		collapsed_attachments_list = !collapsed_attachments_list
	
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
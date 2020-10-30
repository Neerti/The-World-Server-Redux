// Base type for computers which interact with `/datum/persistent_record` types.

/obj/machinery/computer/persistent_record
	name = "generic record console"
	desc = "A console which can interact with information stored off-site."
//	circuit = /obj/item/weapon/circuitboard/persistent_record // TODO
	var/datum/persistent_record/loaded_record = null // Current record being viewed, if any.
	var/loaded_record_file_path = null // Where that current record exists on disk.
	var/datum/persistent_directory/directory = null
	var/directory_type = null
	var/persistent_record_type = null
	var/datum/managed_browser/persistent_record_viewer/record_viewer = null
	var/record_viewer_type = /datum/managed_browser/persistent_record_viewer

/obj/machinery/computer/persistent_record/initialize()
	directory = new directory_type()
	return ..()

/obj/machinery/computer/persistent_record/Destroy()
	if(loaded_record)
		close_record()
	QDEL_NULL(directory)
	return ..()

/obj/machinery/computer/persistent_record/attack_hand(mob/living/user)
	interact(user)
	// TODO
	/*
	var/choice = alert(user, "Test Functions", "Test", "Load Record", "Save Record", "New Record")
	switch(choice)
		if("Load Record")
			choose_record(user)
		if("Save Record")
			Topic(null , list("save_record" = 1))
		if("New Record")
			make_new_record()
	*/






/obj/machinery/computer/persistent_record/proc/close_record()
	if(loaded_record && loaded_record_file_path)
		save_record(loaded_record_file_path)
	QDEL_NULL(loaded_record)
	loaded_record_file_path = null

/obj/machinery/computer/persistent_record/proc/load_record(file_path)
	if(!file_path)
		return
	
	var/datum/persistent_record/R = SSpersistence.json_to_object(SSpersistence.read_json(file_path))
	if(!istype(R))
		return
	
	loaded_record = R
	loaded_record_file_path = file_path

/datum/proc/test_json_serialization()
	to_world(SSpersistence.object_to_json(src))
	var/list/data = save_serialized_data()
	var/json_string = json_encode(data)
	to_world(json_string)

/obj/machinery/computer/persistent_record/proc/save_record(file_path)
	if(!istype(loaded_record))
		return
	if(!file_path)
		return
	var/json_string = SSpersistence.object_to_json(loaded_record)
	SSpersistence.write_json(json_string, file_path)

/obj/machinery/computer/persistent_record/proc/make_new_record(mob/living/user)
	var/datum/persistent_record/R = new persistent_record_type()
	R.on_new_record(user)
	loaded_record = R

/obj/machinery/computer/persistent_record/proc/default_new_record_filepath(datum/persistent_record/R)
	return "[directory.actual_directory][R.unique_id].json"

/obj/machinery/computer/persistent_record/proc/get_all_records()
	return directory.get_all_files(directory.actual_directory)


/obj/machinery/computer/persistent_record/proc/choose_record(mob/living/user)
	var/file_path = directory.choose_file(user, directory.actual_directory)
	if(!file_path)
		return
	load_record(file_path)

/obj/machinery/computer/persistent_record/attackby(I, user)
	if(scan_object(I, user))
		return
	return ..()

// Alternative for above in case something else interacts weirdly.
/obj/machinery/computer/persistent_record/MouseDrop_T(atom/A, mob/living/user)
	if(!istype(user)) // Ghosts go away.
		return
	scan_object(A, user)

/obj/machinery/computer/persistent_record/interact(mob/living/user)
	if(!istype(record_viewer))
		record_viewer = new record_viewer_type(user.client)
	else
		record_viewer.show_to_user(user)
	
/*
	var/list/html = build_window(user)

	var/datum/browser/popup = new(user, "persistent_record", "[src]", 680, 480, src)
	popup.set_content(html.Join())
	popup.open()

	onclose(user, "persistent_record")
*/
// Used to 'upload' specific information to a record, as an attachment.
/obj/machinery/computer/persistent_record/proc/scan_object(obj/item/I, mob/living/user)
	if(record_viewer.loaded_record)
		var/datum/record_attachment/A = I.extract_record_data(user)
		if(istype(A))
			loaded_record.attachments += A
			loaded_record.add_record_log("[user.name] uploaded '[A.title]'.")
			
			visible_message("\The [user] holds \the [I] up to \the [src]'s scanner.")
			playsound(src, 'sound/machines/twobeep.ogg', 25, FALSE)
			interact(user)
			return TRUE
	return FALSE

/obj/machinery/computer/persistent_record/proc/build_window(mob/living/user)
	. = list()
	. += display_file_text()
	. += "<hr>"
	if(loaded_record)
		. += display_record(user, loaded_record)

/obj/machinery/computer/persistent_record/proc/display_record(mob/living/user, datum/persistent_record/R)
	return R.display_html(user)

// Makes the buttons and such for saving/loading/etc records.
// Shown on the top of the window.
/obj/machinery/computer/persistent_record/proc/display_file_text()
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

/obj/machinery/computer/persistent_record/Topic(href, href_list)
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
	
	interact(user) // To refresh the window.


// Connects to the Police DB, and holds stuff like arrest reports, evidence, etc.
/obj/machinery/computer/persistent_record/police
	name = "police case record console"
	desc = "A console used to interact with the GCPD case database."
	req_one_access = list(access_security)
	directory_type = /datum/persistent_directory/police
	persistent_record_type = /datum/persistent_record/police_case
	record_viewer_type = /datum/managed_browser/persistent_record_viewer/police_case


// Connects to both the Police DB and Legal DB, used to file charges against someone.
/obj/machinery/computer/persistent_record/prosecutor
	req_one_access = list(access_prosecutor)

/obj/machinery/computer/persistent_record/court
	name = "legal case record console"
	desc = "A console used to view certain digitized case records."
	directory_type = /datum/persistent_directory/court
	persistent_record_type = /datum/persistent_record/court_case

/obj/machinery/computer/persistent_record/court/default_new_record_filepath(datum/persistent_record/R)
	return "[directory.actual_directory]active/[R.unique_id].json"

// Connects to the Legal DB and allows people to view cases that are public.
/obj/machinery/computer/persistent_record/court/public

// Connects to the Legal DB and is used for judges to write verdicts, set court dates, etc.
/obj/machinery/computer/persistent_record/court/judge
	req_one_access = list(access_judge)

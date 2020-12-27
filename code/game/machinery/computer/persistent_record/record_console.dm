// Base type for computers which interact with `/datum/persistent_record` types.

/obj/machinery/computer/persistent_record
	name = "generic record console"
	desc = "A console which can interact with information stored off-site."
//	circuit = /obj/item/weapon/circuitboard/persistent_record // TODO
	var/datum/managed_browser/persistent_record_viewer/record_viewer = null
	var/record_viewer_type = /datum/managed_browser/persistent_record_viewer

/obj/machinery/computer/persistent_record/Destroy()
	QDEL_NULL(record_viewer)
	return ..()

/obj/machinery/computer/persistent_record/attack_hand(mob/living/user)
	interact(user)

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

// Used to 'upload' specific information to a record, as an attachment.
/obj/machinery/computer/persistent_record/proc/scan_object(obj/item/I, mob/living/user)
	if(record_viewer.loaded_record)
		var/datum/record_attachment/A = I.extract_record_data(user)
		if(istype(A))
			record_viewer.loaded_record.attachments += A
			record_viewer.loaded_record.add_record_log("[user.name] uploaded '[A.title]'.")
			
			visible_message("\The [user] holds \the [I] up to \the [src]'s scanner.")
			playsound(src, 'sound/machines/twobeep.ogg', 25, FALSE)
			interact(user)
			return TRUE
	return FALSE

// Connects to the Police DB, and holds stuff like arrest reports, evidence, etc.
/obj/machinery/computer/persistent_record/police
	name = "police case record console"
	desc = "A console used to interact with the GCPD case database."
	req_one_access = list(access_security)
	record_viewer_type = /datum/managed_browser/persistent_record_viewer/police_case


// Connects to both the Police DB and Legal DB, used to file charges against someone.
/obj/machinery/computer/persistent_record/prosecutor
	req_one_access = list(access_prosecutor)

/obj/machinery/computer/persistent_record/court
	name = "legal case record console"
	desc = "A console used to view certain digitized case records."


// Connects to the Legal DB and allows people to view cases that are public.
/obj/machinery/computer/persistent_record/court/public

// Connects to the Legal DB and is used for judges to write verdicts, set court dates, etc.
/obj/machinery/computer/persistent_record/court/judge
	req_one_access = list(access_judge)

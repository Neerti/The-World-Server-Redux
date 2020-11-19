// A digital police case report, that is saved to the server.
// Can contain forensic evidence, for use in court later on.
/datum/persistent_record/police_case




/obj/verb/test_forensics_data()
	to_chat(usr, extract_record_data())


/obj/proc/extract_record_data(mob/living/user)
	var/obj/item/weapon/card/id/ID = user.GetIdCard()
	if(!istype(ID))
		to_chat(user, SPAN_WARNING("You need to wear an ID to do that."))
		return null
	
	var/datum/record_attachment/A = new()
	A.title = get_record_title()
	A.content = get_record_content()
	A.image_id = get_record_image_id()
	A.uploader_name = ID.registered_name
	A.uploader_ckey = ckey(user.key)
	A.uploader_uid = ID.unique_ID
	return A

/obj/proc/get_record_title()
	return src.name

/obj/proc/get_record_content()
	return desc

/obj/proc/get_record_image_id()
	return null

/obj/item/weapon/photo/get_record_image_id()
	return image_id

/obj/item/weapon/paper/get_record_content()
	return info

/obj/item/weapon/sample/fibers/get_record_content()
	var/list/data = list()

	if(LAZYLEN(evidence))
		data += "Fibers collected:"
		for(var/thing in evidence)
			data += thing
	return data.Join("<br>")

/obj/item/weapon/sample/print/get_record_content()
	var/list/data = list()

	if(LAZYLEN(evidence))
		data += "Fingerprints collected:"
		for(var/thing in evidence)
			data += thing
	return data.Join("<br>")

/*
/obj/item/weapon/paper_bundle/extract_record_data()
	var/list/data = list()

	for(var/thing in pages)
		var/obj/O = thing
		var/list/page_data = O.extract_record_data()
		data += page_data
	return data.Join("<br>")


/obj/item/weapon/reagent_containers/extract_record_data()
	var/list/data = list()
	var/list/reagents_in_object = reagents.reagent_list

	if(LAZYLEN(reagents_in_object))
		data += "Reagents found:"
		for(var/thing in reagents_in_object)
			var/datum/reagent/R = thing
			data += "[R.name] ([R.volume]u)"
			data += "[R.description]<br>" // Extra line break so each reagent is spaced out.
	else
		data += "No reagents found."
	return data.Join("<br>")

*/
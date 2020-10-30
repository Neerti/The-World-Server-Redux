// Counts up every time a new record is created for the round. This is used to help make the ID be unique.
// Note this gets reset every round, but the game ID is also used, so it stays unique regardless.
GLOBAL_VAR_INIT(persistent_record_incrementer, 0)

#define COURT_CASE_FILE_ROOT_DIR "data/persistent/records/court/"
#define COURT_CASE_FILE_ACTIVE_DIR COURT_CASE_FILE_ROOT_DIR+"active/"
#define COURT_CASE_FILE_ARCHIVED_DIR COURT_CASE_FILE_ROOT_DIR+"archived/"



#define POLICE_DATABASE_FILE_ROOT_DIR "data/persistent/records/police/"


// Datum that represents a real directory on disk, that contain files that contain information to reconstruct `/datum/persistent_record` instances.
/datum/persistent_directory
	var/actual_directory = null

// Allows the user to navigate inside the directory, and returns the path of a file that they select, if anything.
// Selecting another directory will open it and let the user continue browsing.
// Users are not allowed to navigate outside of the `actual_directory` path, so players can't do crazy things like reading actual server logs.
// `hide_filetypes` will hide the file extension, e.g. b9x-acsG_2.json, which is useful if this is being used in an IC context, verses an OOC one (admin verbs).
/datum/persistent_directory/proc/browse_directory(mob/user, hide_filetypes = TRUE, specific_directory = actual_directory)
	var/current_dir = specific_directory
	if(!current_dir)
		current_dir = actual_directory
	
	var/finished = FALSE
	while(!finished)
		if(!findtext(current_dir, actual_directory)) // Somehow they got out. Commit sudoku.
			log_and_message_admins("was browsing the persistent directory '[type]', \
			and escaped its root directory '[actual_directory]', going into '[current_dir]'. Browsing aborted.", user)
			return null
		
		var/list/choices = list()

		if(current_dir != actual_directory)
			choices += ".."
		
		choices += flist(current_dir)

		var/dir_to_display = current_dir // TODO don't show '/data/persistence/records/whatever'
		if(hide_filetypes)
			dir_to_display = replacetext(dir_to_display, actual_directory, "/")
		
		var/choice = input(user, "Choose a file or directory to open.\n\
		Current directory is [current_dir].\n\
		Hit Cancel to abort.", "Directory Navigation") as null|anything in choices
		
		if(isnull(choice)) // User clicked Cancel.
			return null
		if(copytext("[choice]", -1) == "/" || (choice == ".." && current_dir != actual_directory)) // User clicked on another directory.
			if(choice == "..")
				return // TODO find a way to get the parent path.
			else
				current_dir = "[current_dir][choice]"
		else // User clicked a file.
			return "[current_dir][choice]"

// Recursively retrieves all file paths in the represented directory.
// Note that this retrieves strings of file paths, NOT file objects, like the link below has.
// This is so the paths can be manipulated, e.g. prior to showing to the user.
// Adapted from http://www.byond.com/forum/post/2424819
/datum/persistent_directory/proc/get_all_files(file_path, recursive = TRUE)
	if(!file_path)
		file_path = actual_directory
	
	. = list()

	for(var/file_name in flist(file_path))
		if(is_directory(file_name) && recursive)
			. += .("[file_path][file_name]")
		else
			. += "[file_path][file_name]"

/datum/persistent_directory/proc/is_directory(file_path)
	return copytext("[file_path]", -1) == "/"

/datum/persistent_directory/proc/choose_file(mob/user, file_path)
	var/list/actual_file_paths = get_all_files(file_path)
	var/list/cleaned_file_paths = list()
	for(var/thing in actual_file_paths)
		var/cleaned_path = replacetext(thing, actual_directory, "/")
		cleaned_path = replacetext(cleaned_path, ".json", "")
		cleaned_file_paths += cleaned_path
	
	var/choice = input(user, "Choose a file.", "File Selection") as null|anything in cleaned_file_paths
	if(isnull(choice))
		return
	var/index_chosen = cleaned_file_paths.Find(choice)
	return actual_file_paths[index_chosen]

/datum/persistent_directory/court
	actual_directory = COURT_CASE_FILE_ROOT_DIR

/datum/persistent_directory/court/proc/get_all_archieved_paths()
	return flist(COURT_CASE_FILE_ARCHIVED_DIR)

// Called on server initialization, to ""move"" aging files from the active dir to the archive one.
/datum/persistent_directory/court/proc/manage_expiring_cases()
	for(var/filename in flist(COURT_CASE_FILE_ACTIVE_DIR))
		var/full_filepath = COURT_CASE_FILE_ACTIVE_DIR+filename // E.g. data/persistent/records/court/active/b9x-acsG_2.json
		var/json_string = SSpersistence.read_json(full_filepath)
		var/datum/persistent_record/court_case/C = SSpersistence.json_to_object(json_string)
		if(C.is_expired())
			fcopy(full_filepath, COURT_CASE_FILE_ARCHIVED_DIR+filename)
		//	fdel(full_filepath) // TODO
			log_world("Court case '[filename]' expired, and was moved to archive directory.")
//		var/datum/persistent_record/court_case/C = read_json(full_filepath)
//		if(C.is_expired())
//			fcopy(full_filepath, COURT_CASE_FILE_ARCHIVED_DIR+filename)
//			fdel(full_filepath) // TODO
//			log_world("Court case '[filename]' expired, and was moved to archive directory.")


/datum/persistent_directory/police
	actual_directory = POLICE_DATABASE_FILE_ROOT_DIR
/*

/client/verb/test_make_new_persistent_record()
	var/datum/persistent_record/court_case/C = new()
	C.on_new_record()
	var/datum/persistent_directory/court/court_dir = new()
//	court_dir.write_json(COURT_CASE_FILE_ACTIVE_DIR+C.unique_id+".json", C)

/client/verb/test_open_persistent_record()
	var/datum/persistent_directory/court/court_dir = new()
	var/list/records = flist(COURT_CASE_FILE_ACTIVE_DIR)
	var/choice = input(usr, "Choose a record to open.", "Record test") as null|anything in records
	if(!choice)
		return
	var/full_filepath = COURT_CASE_FILE_ACTIVE_DIR+choice
	var/datum/persistent_record/R = SSpersistence.json_to_object(SSpersistence.read_json(full_filepath))
//	var/datum/persistent_record/R = court_dir.read_json(full_filepath)
	debug_variables(R)

/client/verb/test_directory_browser()
	var/datum/persistent_directory/court/court_dir = new()
	var/thing = court_dir.browse_directory(usr)
	to_world(thing)

/client/verb/test_get_all_files()
	var/datum/persistent_directory/court/court_dir = new()
	var/list/paths = court_dir.get_all_files()
	for(var/thing in paths)
		to_world(thing)
*/

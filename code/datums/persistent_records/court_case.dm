// A datum that holds information about a specific case for the court.

// Base type. Use a subtype instead.
/datum/persistent_record/court_case
	// Dates, in DD/MM/YYYY format.
	var/creation_date = null
	var/court_date = null
	var/expiration_date = null

	// Status
	var/visibility = CASE_HIDDEN
	var/case_outcome = CASE_ONGOING
	var/case_status = CASE_STATUS_ACTIVE

	// People involved.
	var/list/witnesses = null
	var/list/plaintiffs = list("name" = "", "unique_id" = "")
	var/list/defendants = list("name" = "", "unique_id" = "")

	var/author = null
	var/desired_outcome = null

	var/list/evidence = null

/datum/persistent_record/court_case/on_new_record()
	creation_date = full_game_time()
	expiration_date = AddDays(creation_date, COURT_CASE_DEFAULT_EXPIRATION_DELAY)
	return ..()

/datum/persistent_record/court_case/proc/is_expired()
	return TRUE // TODO

/datum/persistent_record/court_case/save_serialized_data()
	. = ..()

	.[NAMEOF(src, creation_date)] = creation_date
	.[NAMEOF(src, expiration_date)] = expiration_date
	.[NAMEOF(src, court_date)] = court_date

	.[NAMEOF(src, visibility)] = visibility
	.[NAMEOF(src, case_outcome)] = case_outcome
	.[NAMEOF(src, case_status)] = case_status

	.[NAMEOF(src, witnesses)] = witnesses
	.[NAMEOF(src, plaintiffs)] = plaintiffs
	.[NAMEOF(src, defendants)] = defendants

	.[NAMEOF(src, author)] = author
	.[NAMEOF(src, desired_outcome)] = desired_outcome

/datum/persistent_record/court_case/load_deserialized_data(list/data)
	..()
	creation_date = data[NAMEOF(src, creation_date)]
	expiration_date = data[NAMEOF(src, expiration_date)]
	court_date = data[NAMEOF(src, court_date)]

	visibility = data[NAMEOF(src, visibility)]
	case_outcome = data[NAMEOF(src, case_outcome)]
	case_status = data[NAMEOF(src, case_status)]

	witnesses = data[NAMEOF(src, witnesses)]
	plaintiffs = data[NAMEOF(src, plaintiffs)]
	defendants = data[NAMEOF(src, defendants)]

	author = data[NAMEOF(src, author)]
	desired_outcome = data[NAMEOF(src, desired_outcome)]

// For when someone wants to sue someone else.
/datum/persistent_record/court_case/civil

// For when the Prosecutor wants the death penalty.
/datum/persistent_record/court_case/criminal
	var/list/charges_brought = null
	var/list/charges_applied = null

// For when the state gets sued.
/datum/persistent_record/court_case/colonial

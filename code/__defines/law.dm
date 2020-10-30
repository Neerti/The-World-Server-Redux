// Case Types
/*
#define CRIMINAL_CASE "Criminal"						// for criminal cases.
#define CIVIL_CASE "Civil"							// divorcing your wife.
#define COLONIAL_CASE "Colonial"						// checking your colon-- suing the state.
#define OTHER_CASE "Other"							// some kind of snowflake case that doesn't fit with the above.
*/

// Case Outcomes

#define ALL_CASE_OUTCOMES list(CASE_ONGOING, CASE_SETTLED, CASE_SETTLED_EXTERNAL, CASE_AWAITING_TRIAL, CASE_DROPPED, CASE_REJECTED)

#define CASE_ONGOING			"Ongoing"				// case is still going on.
#define CASE_SETTLED			"Settled"				// for civil court cases that got settled.
#define CASE_SETTLED_EXTERNAL	"Settled Externally"	// 
#define CASE_AWAITING_TRIAL		"Awaiting Trial"		
#define CASE_DROPPED			"Dropped"				// cases that got cancelled.
#define CASE_REJECTED			"Rejected"				// invalid cases cancelled by the judge, or the high court - "I'M SUING THE PRESIDENT BECAUSE HE'S GAY".


// Case Statuses

#define CASE_STATUS_ACTIVE "Active"
#define CASE_STATUS_ARCHIVED "Archived"
#define CASE_STATUS_EXPIRED "Expired"					// cases that went nowhere and ended up expiring.

// Case Representation Status

#define CASE_REPRESENTATION_NEEDED "Legal Representation Requested"
#define CASE_REPRESENTATION_UNWANTED "Self-Represented"
#define CASE_REPRESENTATION_REPRESENTED "Legally Represented"

// Case visibility

#define CASE_PUBLIC "Public"
#define CASE_HIDDEN "Hidden" 

#define COURT_CASE_DEFAULT_EXPIRATION_DELAY 7 // In days.
# evergreen_oclc_sync_tools
This script provides checks a list of OCLC numbers for current holdings in an Evergreen catalog

To use it:

* Use OCLC worldshare to generate a list of all the OCLC numbers your institution is marked as Held.
* Use Evergreen's reporter (or just SQL) to generate a list of all the items you'd like to add OCLC holdings for -- you will want Evergreen's database IDs (biblio.record_entry.id).
* Download this repo, and replace the Evergreen info in .env with your own info if necessary
* Run `bundle`
* Run `bundle exec deletes [PATH_TO_OCLC_NUMBER_FILE]` against your list of current OCLC holdings.  This will print to screen a list of OCLC numbers for titles that you no longer hold, or are not loanable, which you can use to delete holdings in OCLC.
* Run `bundle exec adds [PATH_TO_EG_DB_ID_FILE]` against your list of Evergreen record IDs.  This will print to screen a list of OCLC numbers for titles that you totally should mark as Held in OCLC.

I typically use OCLC Connexion Client to process the big lists of OCLC numbers to add or delete, but there are probably other ways to do it. :-)

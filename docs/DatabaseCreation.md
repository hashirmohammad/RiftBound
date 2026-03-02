**Database Creation System**



**Overview:**



The Database Creation feature establishes the foundational data system for the Riftbound online platform. Its purpose is to store, structure, and load all card definitions required for gameplay in a scalable and maintainable way.



Instead of hardcoding card values directly in Godot, this system separates card data from game logic using a CSV → JSON pipeline. This allows card information to be easily edited, version-controlled, and loaded dynamically into the engine.



**Purpose:**



The goals of this feature are:



* Centralize all card data in one structured format
* Allow non-programmers to edit card information through Google Sheets
* Maintain version control over card definitions
* Separate static card data from runtime game state
* Provide a scalable foundation for future features
* This design follows professional software engineering principles such as separation of concerns and modular architecture.



**System Architecture:**



The database system follows this pipeline:



Google Sheets (Card Authoring)

↓

Export as CSV

↓

csv\_to\_json.py script

↓

cards.json

↓

Godot CardDB Loader



This ensures a clean transformation from editable spreadsheet data into structured backend data usable by the engine.



**Data Structure:**



Each card in cards.json contains structured information such as:



* card\_id
* set\_code
* name
* cost (Energy)
* might
* domain
* type
* keywords (array parsed from Tags)
* rules\_text (Ability description)
* rarity
* artist
* image\_url



Example JSON structure:



{

&nbsp; "card\_id": "OGN-010/298",

&nbsp; "set\_code": "Origins",

&nbsp; "name": "Legion Rearguard",

&nbsp; "cost": 2,

&nbsp; "might": 2,

&nbsp; "domain": "Fury",

&nbsp; "type": "Unit",

&nbsp; "keywords": \["Trifarian", "Noxus"],

&nbsp; "rules\_text": "...",

&nbsp; "rarity": "Common",

&nbsp; "artist": "Six More Vodka",

&nbsp; "image\_url": "..."

}



**Conversion Script:**



The file tools/csv\_to\_json.py is responsible for converting the exported CSV into structured JSON.



Responsibilities of the script:



* Parse numeric fields (Energy, Might)
* Convert comma-separated Tags into an array
* Normalize whitespace
* Output properly formatted JSON
* Maintain consistent schema



Command used to generate JSON:



python tools/csv\_to\_json.py data/cards.csv data/cards.json



The resulting cards.json file is committed to the repository.



**Godot Integration**



The CardDB system loads cards.json at runtime and stores card data in memory.



Responsibilities of CardDB:



* Load JSON file
* Index cards by card\_id
* Provide lookup methods for gameplay systems
* Allow card data retrieval for UI rendering and game logic



Example usage in GDScript:



var card = CardDB.get\_card("OGN-010/298")

print(card\["name"])


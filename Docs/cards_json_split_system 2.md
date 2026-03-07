**Card JSON Split System**



**Overview:**



This feature introduces a system that separates the combined cards.json file into individual JSON files for each card. Instead of storing all cards inside one large JSON array, each card is now stored in its own JSON file.



The purpose of this change is to improve organization, maintainability, and scalability of the card database system. By separating cards into individual files, developers can access, modify, and manage card data more easily without needing to navigate a single large data file.



**Purpose:**



The goals of this system are:



* Improve data organization for the card database
* Allow easier modification of individual cards
* Reduce the risk of merge conflicts when multiple developers modify card data
* Make card loading and indexing more flexible in the backend
* Improve scalability as the number of cards increases



This change supports long-term development of the Riftbound platform by making the card data structure more modular.



**System Structure:**



Previously, all card data was stored in one file:



data/cards.json



This file contained an array with every card definition. The new structure separates each card into its own file inside a new directory.



**Updated Structure:**



riftbound/

&nbsp; data/

&nbsp;   cards.json

&nbsp;   cards/

&nbsp;     Legion\_Rearguard.json

&nbsp;     Magma\_Wurm.json

&nbsp;     Noxus\_Hopeful.json

&nbsp;     Pouty\_Poro.json

&nbsp;     ...

&nbsp; tools/

&nbsp;   split\_cards\_json.py

&nbsp; docs/

&nbsp;   card\_json\_split\_system.md



The folder data/cards/ now stores all individual card JSON files.



**How the System Works:**



The system uses a Python script to automatically convert the master card list into individual files.



**Workflow:**



1. Card data is originally stored in cards.json.
2. A script reads the JSON array of cards.
3. Each card object is extracted individually.
4. A new JSON file is created for that card.
5. The file is saved in the data/cards/ directory using the card's name as the filename.



**Conversion Script:**



The script responsible for splitting the card database is located at:



tools/split\_cards\_json.py



**Responsibilities of the Script:**



The script performs the following tasks:



* Loads the master cards.json file
* Iterates through each card entry
* Extracts the card name
* Creates a safe filename
* Writes the card data into an individual JSON file
* Stores the file in data/cards/



This process is automated and ensures consistent formatting across all card files.



**Running the Script:**



To generate the individual card files, run the following command from the project root directory:



python tools/split\_cards\_json.py data/cards.json data/cards



or



py tools/split\_cards\_json.py data/cards.json data/cards



After running the script, the data/cards/ directory will contain a JSON file for each card.


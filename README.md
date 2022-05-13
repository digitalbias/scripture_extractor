# Scripture Extractor

Wrote it in a weekend and it's really ugly, but it gets the job done. 

I really just wanted to have some scriptures in a markdown format that I could reference so I found a sqlite3 database out there I could use. I've been using Obsidian for a while now and wanted a vault where I could study the scriptures and also make comments and create links in a more portable, free form manner than what I have found in other systems.

 This project takes the sqlite database, pulls out the verses and creates a series of folders. One for the particular volume (like The Old Testament) and then another subfolder for each book in it (i.e. Genesis). It creates a markdown file for each chapter and also creates index files for the volume and books. It scratches my itch for now, but it could really use some better cleanup to make it more efficient and less resource hungry...and more "elixiry"

## Installation & Running it

Steps: 
1. Clone the repo
2. `mix deps.get`
3. Download the LDS scripture library from https://scriptures.nephi.org/ and run the script that creates the "scripture" view
4. Check the `.env` file to make sure it points at where you have the sqlite3 db file and that the output directory is where you want it
5. `make`
6. You should be done

If all you are interested in is the markdown files themselves, you can get them [here](https://github.com/digitalbias/scripture_extractor/releases/tag/0.1)
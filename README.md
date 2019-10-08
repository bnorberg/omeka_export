# Configure API on site 
 	- Go to [site]/admin/settings/edit-api
	- click checkbox "Enable API"
	-  Make sure to change “Results per Page” to a number equal to or greater to the number of items in the site (the script does not do paging)

# api key for user
	- Go to [site]/admin/users
	- find user you want to give API access to (maybe use service account TTS) and edit the user's profile
	- click the API Keys tab, give the key a label and hit the "Update API Keys" button

I haven’t turned the script into a gem so you will have to manually install dependencies. Go to the directory where you downloaded script and run (the later two are only needed if the Omeka site uses the Geolocation plugin):
	- gem install rest
	- gem install csv
	- gem install recursive-open-struct
	- gem install json
	- gem install geocoder
	- gem install countries

# Run script

Open irb from directory the script is downloaded in.

From irb, type “load ‘[path/to/file]/omeka_export.rb’”

## Instantiate your client

client = OmekaExport.new(“[site_url]/api”, “[api_key]”) 

example: client = OmekaExport.new("https://migrationmemorials.trinity.duke.edu/api", "bcfa788c7aa95624510f461e380ceb5ba79b45b2")

## Get items
items = client.items

Separates items by their item type into separate csv files in the same directory the script is run from.

## Get collections
collections = client.collections

## Get item_types
item_types = client.item_types

## Get exhibits
exhibits = client.exhibits

## Get geolocations
geolocations = client.geolocations


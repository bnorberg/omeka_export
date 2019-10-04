require 'rubygems'
require 'csv'
#require 'omeka_client'
require 'rest'
#require 'net/http'
require 'countries'
require 'geocoder'
require 'recursive-open-struct'
require 'json'

class OmekaExport

	 attr_accessor :endpoint, :api_key, :connection

	def initialize(endpoint, api_key = nil)
		@endpoint = endpoint
    	@api_key = api_key
    	@connection = Rest::Client.new
	end

	def get(resource, id = nil, query = {} )
		build_request("get", resource, id, nil, query)
    end


    ###### High level index calls

	def items
		response = self.get('items').body
		items = JSON.parse(response)
		parse_items(items)
		return items
	end

	def site
		response = self.get('site').body
		site = JSON.parse(response)
		return site
	end

	def collections
		begin
			response = self.get('collections').body
			collections = JSON.parse(response)
			parse_collections(collections) unless collections.empty?
			return collections
		rescue Exception => e
			puts "No collections on this site"
		end
	end

	def files
		response = self.get('files').body
		files = JSON.parse(response)
		return files
	end

	def item_types
		response = self.get('item_types').body
		item_types = JSON.parse(response)
		parse_itemtypes(item_types)
		return item_types
	end

	def exhibits
		begin
			response = self.get('exhibits').body
			exhibits = JSON.parse(response)
			parse_exhibits(exhibits) unless exhibits.empty?
			return exhibits
		rescue Exception => e
			puts "No exhibits on this site"
		end
	end

	def exhibit_pages
		#begin
			response = self.get('exhibit_pages').body
			exhibit_pages = JSON.parse(response)
			parse_exhibitpages(exhibit_pages) unless exhibit_pages.empty?
			return exhibit_pages
		#rescue Exception => e
		#	puts "No exhibit pages on this site"
		#end
	end

	def basic_pages
		begin
			response = self.get('simple_pages').body
			pages = JSON.parse(response)
			parse_pages(pages) unless pages.empty?
			return pages
		rescue Exception => e
			puts "No basic pages on this site"
		end
	end

	def geolocations
		begin
			response = self.get('geolocations').body
			geolocations = JSON.parse(response)
			parse_geolocations(geolocations) unless geolocations.empty?
			return geolocations
		rescue Exception => e
			puts "Geolocations wasn't used on this site"
		end
	end

	###### Individual object calls

	def collection_title(id)
		begin
			response = self.get('collections', id).body
			collection = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
			title = collection.element_texts[0].text
			return title
		rescue Exception => e
			response = e
		end
	end

	def item_title(id)
		begin
		response = self.get('items', id).body
		item = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
		title = item.element_texts[0].text
		return title
		rescue Exception => e
			puts "This item no longer exists"
		end
	end

	def exhibit_page_title(id)
		response = self.get('exhibit_pages', id).body
		exp_titles =[]
		exhibit_pages = JSON.parse(response)
		exhibit_pages.each do |ep|
			page = RecursiveOpenStruct.new(ep,:recurse_over_arrays => true)
			exp_titles << page.title
		end
			processed_page_titles = exp_titles.map { |t| t.to_s}.join("||").gsub("||,", "||").chomp("||")
		return processed_page_titles
	end

	def basic_page_title(parent_info)
		if !parent_info.nil?
			response = self.get('simple_pages', parent_info['id']).body
			basic_page = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
			bp_title = basic_page.title
		else
			bp_title = nil
		end
		return bp_title
	end

	def parent_page_title(id)
		response = self.get('parent_page', id).body
		exhibit_page = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
		title = exhibit_page.title
		return title
	end

	def element_info(id)
		response = self.get('elements', id).body
		element = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
		name = element.name
		description =  element.description
		return "#{name}, #{description}"
	end

	def users(id)
		response = self.get('users', id).body
		user = JSON.parse(response)
		return user
	end

	def item_types_name(id)
		response = self.get('item_types', id).body
		item_type = RecursiveOpenStruct.new(JSON.parse(response), :recurse_over_arrays => true)
		name =  item_type.name
		return name
	end

	def file_url(id)
		response = self.get('files?item', id).body
		all_files =[]
		files = JSON.parse(response)
		if !files.empty?
			files.each do |file|
				file_url = file['file_urls']['original']
				all_files << file_url
			end
		end
		processed_files = all_files.map { |t| t.to_s}.join(",")
		return processed_files
	end


private

### Build REST API call url

    def build_request(method, resource = nil, id = nil, body =nil, query = {})

      url =  self.endpoint
      url += "/" + resource unless resource.nil? || resource == "parent_page"
      if resource == "exhibit_pages"
      	url += "?exhibit=" + id.to_s unless id.nil?
      elsif resource == "parent_page"
      	url += "/exhibit_pages/" + id.to_s
      elsif resource == "files?item"
      	url += "=" + id.to_s unless id.nil?
      else
      	url += "/" + id.to_s unless id.nil?
      end
      	query[:key] = self.api_key unless self.api_key.nil?

      case method
      when "get"
        self.connection.get(url, :params => query)
      end

    end

    def parse_items(items)
    	parsed_items = []
    	items.each do |i|
			item = RecursiveOpenStruct.new(i, :recurse_over_arrays => true)
			parsed_items << item
		end
		#create_items_csv(parsed_items)
		split_itemtype(parsed_items)
    end

     def parse_collections(collections)
    	parsed_collections = []
    	collections.each do |c|
			collection = RecursiveOpenStruct.new(c, :recurse_over_arrays => true)
			parsed_collections << collection
		end
		create_collections_csv(parsed_collections)
    end

     def parse_geolocations(geolocations)
    	parsed_geolocations = []
    	geolocations.each do |c|
			geolocation = RecursiveOpenStruct.new(c, :recurse_over_arrays => true)
			parsed_geolocations << geolocation
		end
		create_geolocation_csv(parsed_geolocations)
    end

     def parse_exhibits(exhibits)
    	parsed_exhibits = []
    	exhibits.each do |ex|
			exhibit = RecursiveOpenStruct.new(ex, :recurse_over_arrays => true)
			parsed_exhibits << exhibit
		end
		create_exhibits_csv(parsed_exhibits)
    end

    def parse_pages(pages)
    	parsed_pages = []
    	pages.each do |p|
			page = OpenStruct.new(p)
			parsed_pages << page
		end
		create_pages_csv(parsed_pages)
    end

    def parse_itemtypes(item_types)
    	parsed_itemtypes = []
    	item_types.each do |it|
			item_type = RecursiveOpenStruct.new(it, :recurse_over_arrays => true)
			parsed_itemtypes << item_type
		end
		create_itemtypes_csv(parsed_itemtypes)
    end

    def parse_exhibitpages(exhibit_pages)
    	exp_parsed = []
			exhibit_pages.each do |ep|
			page = RecursiveOpenStruct.new(ep,:recurse_over_arrays => true)
			exp_parsed << page
		end
		create_exhibitpages_csv(exp_parsed)
		create_exhibitpages_blocks_csv(exp_parsed)
		create_exhibitpages_block_items_csv(exp_parsed)
	end

	def split_itemtype(parsed_items)
		sound_items = []
		image_items = []
		text_items = []
		moving_image_items = []
		oral_history_items = []
		website_items = []
		event_items = []
		email_items = []
		hyperlink_items = []
		lesson_plan_items = []
		person_items = []
		interactive_resource_items = []
		dataset_items = []
		physical_object_items = []
		service_items = []
		software_items = []
		memorial_items = []
		#add variable for new item type here item_type_name =[]
		nil_items = []
		parsed_items.each do |item|
			if 	!item_type_nil_check(item.item_type).nil?
				if item_type_nil_check(item.item_type).downcase == "sound"
					sound_items << item
				elsif item_type_nil_check(item.item_type).downcase == "still image"
					image_items << item
				elsif item_type_nil_check(item.item_type).downcase == "text"
					text_items << item
				elsif item_type_nil_check(item.item_type).downcase == "moving image"
					moving_image_items << item
				elsif item_type_nil_check(item.item_type).downcase == "oral history"
					oral_history_items << item
				elsif item_type_nil_check(item.item_type).downcase == "website"
					website_items << item
				elsif item_type_nil_check(item.item_type).downcase == "event"
					event_items << item
				elsif item_type_nil_check(item.item_type).downcase == "email"
					email_items << item
				elsif item_type_nil_check(item.item_type).downcase == "hyperlink"
					hyperlink_items << item
				elsif item_type_nil_check(item.item_type).downcase == "lesson plan"
					lesson_plan_items << item
				elsif item_type_nil_check(item.item_type).downcase == "person"
					person_items << item
				elsif item_type_nil_check(item.item_type).downcase == "interactive resource"
					interactive_resource_items << item
				elsif item_type_nil_check(item.item_type).downcase == "dataset"
					dataset_items << item
				elsif item_type_nil_check(item.item_type).downcase == "physical object"
					physical_object_items << item
				elsif item_type_nil_check(item.item_type).downcase == "service"
					service_items << item
				elsif item_type_nil_check(item.item_type).downcase == "software"
					software_items << item
				elsif item_type_nil_check(item.item_type).downcase == "memorial"
					memorial_items << item	
				end
				#and new elsif statement for new item type
				#elsif item_type_nil_check(item.item_type).downcase == "name_of_item_type"
				#	name_of_array_created_in_line_309 << item	
				#end
			else
				nil_items << item
			end
		end
		create_sound_items_csv(sound_items, "sound")
		create_image_items_csv(image_items, "still_image")
		create_text_items_csv(text_items, "text")
		create_moving_image_items_csv(moving_image_items, "moving_image")
		create_oral_history_items_csv(oral_history_items, "oral_history")
		create_website_items_csv(website_items, "website")
		create_hyperlink_items_csv(hyperlink_items, "hyperlink")
		create_event_items_csv(event_items, "event")
		create_person_items_csv(person_items, "person")
		create_email_items_csv(email_items, "email")
		create_lesson_plan_items_csv(lesson_plan_items, "lesson_plan")
		create_items_csv(interactive_resource_items, "interactive_resource")
		create_items_csv(dataset_items, "dataset")
		create_items_csv(physical_object_items, "physical_object")
		create_items_csv(service_items, "service")
		create_items_csv(software_items, "software")
		create_memorial_csv(memorial_items, "memorial")
		#create_name_of_item_type_csv(name_of_array_line_309, "new_item_type")
		create_items_csv(nil_items, "none")
	end

	def title_nil_check(item)
		if !item.nil?
			title = item.text
		else
			title = nil
		end
		return title
	end

    def md_nil_check(element, md_name)
    	#puts "start of field"
    	#puts element
    	if !element.nil?
    		if !element.empty?
    			md_type = element.element_set.name
    			key = "#{md_type}:#{element.element.name}"
    			#puts element.text
    			#puts md_name
    			#puts key
	    		#puts key == md_name
	    		#puts "*****************"
    			if key == md_name
    				md_value = element.text
    				#puts md_value
    				#puts '++++++++++++'
    			else
    				@md_hash[key] = element.text
    				@md_hash.keys.each do |hk|
    					#puts "[[[[[[[[[["
    					#puts hk
    					#puts md_name
    					#puts "]]]]]]]]]]"
    					if hk == md_name
    						md_value = @md_hash[hk]
    						@md_hash.delete(hk)
    						#puts md_value
    						#puts '^^^^^^^^^^^^^^^^^^^^^^^'
    						#puts "found match"
    					else
    						#puts "no match"
    						#puts hk
    						#puts md_name
    						#puts element.text
    						#puts '||||||||||||||||||||||||'
    					end
    				end
				end
			else
				md_value = nil
				#puts md_value
				#puts '######################'
    		end
    	else
    		@md_hash.keys.each do |hk|
				#puts "[[[[[[[[[["
				#puts hk
				#puts md_name
				#puts "]]]]]]]]]]"
				if hk == md_name
					md_value = @md_hash[hk]
					@md_hash.delete(hk)
					#puts md_value
					#puts '^^^^^^^^^^^^^^^^^^^^^^^'
					#puts "found match"
				else
					#puts "no match"
					#puts hk
					#puts md_name
					#puts '||||||||||||||||||||||||'
				end
    		end
    		#puts md_value
    		#puts '================='
    	end
    	#puts md_value
    	#puts '-------------'

    	#puts "end of field"
    	return md_value
    end

    def collection_nil_check(collection)
    	if !collection.nil?
    		title = self.collection_title(collection.id)
    	else
    		title = nil
    	end
    	return title
    end

     def item_type_nil_check(itemtype)
    	if !itemtype.nil?
    		name = self.item_types_name(itemtype.id)
    	else
    		name = nil
    	end
    	return name
    end

     def url_nil_check(file)
    	if !file.nil?
    		url = self.file_url(file.url.split("=")[1])
    	else
    		url = nil
    	end
    	return url
    	get_first_url(url)
    end

    def get_first_url(file)
    	if !file.nil?
    		furl = self.file_url(file.url.split("=")[1]).split(",").first
    	else
    		furl = nil
    	end
    	return furl
    end	

    def element_name_nil_check(name)
    	if !name.nil?
    		element_name = name.split(",")[0]
    	else
    		element_name = nil
    	end
    	return element_name
    end

     def element_desc_nil_check(desc)
    	if !desc.nil?
    		element_desc = desc.split(",")[1]
    	else
    		element_desc = nil
    	end
    	return element_desc
    end

   def page_block_titles(blocks)
    	page_block_titles =[]
    	blocks.each do |block|
    		block_title = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibit_block_#{block.id}"
    		page_block_titles << block_title
    	end
    		processed_block_titles = page_block_titles.map { |pbi| pbi.to_s}.join(",")
    	return processed_block_titles
    end

     def page_block_parent(parent)
     	if !parent.nil?
    		page_title = parent_page_title(parent.id)
    		#puts page_title
    		#puts "++++++++++++"
    	else
    		page_title = nil
    	end
    	return page_title
    end

    def attachment_item(attachments)
    	attachment_items =[]
    	attachments.each do |attachment|
    		if !attachment.empty?
    			item_reference = item_title(attachment.item.id)
    			attachment_items << item_reference
    		end
    	end
    	processed_attached_items = attachment_items.map { |ai| ai.to_s}.join("||").gsub("||,", "||").chomp("||")
    	return processed_attached_items
    end


    def attachment_caption(attachments)
    	attachment_captions =[]
    	attachments.each do |attachment|
    		if !attachment.empty?
    			item_caption = attachment.caption
    			attachment_captions << item_caption
    		end
    	end
    	processed_attached_captions = attachment_captions.map { |ac| ac.to_s}.join("||").gsub("||,", "||").chomp("||")
    	return processed_attached_captions
    end

    def attachment_titles(block_id, attachments)
    	attachment_titles =[]
    	i = 0
    	attachments.each do |attachment|
    		if !attachment.empty?
    			i = i+=1
    			title = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_epb#{block_id}_item#{attachment.id}"
    			attachment_titles << title
    		end
    	end
    	processed_titles = attachment_titles.map { |at| at.to_s}.join(",")
    	return processed_titles
    end

    def split_option_position(options)
    	if !options.nil?
    		options = options.to_hash
    		if options.keys.include?(:"showcase-position")
    			position = options[:"showcase-position"]
    		else
    			position = options[:"file-position"]
    		end
    	end
    	return position
    end

    def split_option_gallery(options)
		if !options.nil?
    		options = options.to_hash
    		if options.keys.include?(:"showcase-position")
    			gallery_position = options[:"gallery-position"]
    		else
    			gallery_position = nil
    		end
    	end
    	return gallery_position
    end

    def split_option_filesize(options)
    	if !options.nil?
    		options = options.to_hash
    		file_size = options[:"file-size"]
    	end
    	return file_size
    end

    def split_option_caption_position(options)
    	if !options.nil?
    		options = options.to_hash
    		caption_position = options[:"captions-position"]

    	end
    	return caption_position
    end


    def collect_tags(tags)
    	all_tags = []
    	if !tags.nil?
    		if !tags.empty?
	    		tags.each do |tag|
    				all_tags << tag.name
    			end
    			processed_tags = all_tags.map { |t| t.to_s}.join(",")
    		else
    			processed_tags = nil
    		end
    	end
    	return processed_tags
    end

###Create csv files for different item types

	#def create_sound_items_csv(sound_items, name)
	#	if !sound_items.empty? #change sound_items to name of new item type array in line 309
	#		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
	#		@md_hash = Hash.new
	#		CSV.open(csv_file, 'ab') do |csv|
	#			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
	#		  	if file.none?
			  		#change heading to match those of the new item type
	#		    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_transcription", "it_original_format", "it_duration", "it_bitrate", "collection_reference", "itemtype_reference", "file_url", "tags"]
	#		  	end
	#			 sound_items.each do |item| #change sound_items to name of new item type array in line 309
	#    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Transcription"), md_nil_check(item.element_texts[16], "Item Type Metadata:Original Format"),md_nil_check(item.element_texts[17], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[18], "Item Type Metadata:Bit Rate/Frequency"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags)]
	#    		end
	#  		end
	#  	end
  	#end


	def create_sound_items_csv(sound_items, name)
		if !sound_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_transcription", "it_original_format", "it_duration", "it_bitrate", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 sound_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Transcription"), md_nil_check(item.element_texts[16], "Item Type Metadata:Original Format"),md_nil_check(item.element_texts[17], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[18], "Item Type Metadata:Bit Rate/Frequency"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_memorial_csv(memorial_items, name)
		if !memorial_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_description", "it_institution", "it_type", "it_dedication_date", "it_historical_date", "it_url", "it_aspects", "it_themes", "group_represented", "location", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 memorial_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Memorial Decription"), md_nil_check(item.element_texts[16], "Item Type Metadata:Institution"),md_nil_check(item.element_texts[17], "Item Type Metadata:Official/Unofficial"), md_nil_check(item.element_texts[18], "Item Type Metadata:Date of Dedication"), md_nil_check(item.element_texts[19], "Item Type Metadata:Date Refers to"), md_nil_check(item.element_texts[20], "Item Type Metadata:URL"), md_nil_check(item.element_texts[21], "Item Type Metadata:Physical Aspects"), md_nil_check(item.element_texts[21], "Item Type Metadata:Themes"), md_nil_check(item.element_texts[23], "Item Type Metadata:Nation-State"), md_nil_check(item.element_texts[24], "Item Type Metadata:LocationMem"), collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_moving_image_items_csv(moving_image_items, name)
  		if !moving_image_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_transcription", "it_original_format", "it_duration", "it_compression", "it_producer", "it_director", "it_player", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 moving_image_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Transcription"), md_nil_check(item.element_texts[16], "Item Type Metadata:Original Format"),md_nil_check(item.element_texts[17], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[18], "Item Type Metadata:Compression") , md_nil_check(item.element_texts[19], "Item Type Metadata:Producer") , md_nil_check(item.element_texts[20], "Item Type Metadata:Director"), md_nil_check(item.element_texts[21], "Item Type Metadata:Player"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_oral_history_items_csv(oral_history_items, name)
  		if !oral_history_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_interviewer", "it_interviewee", "it_location", "it_transcription", "it_original_format", "it_duration", "it_bitrate", "it_time_summary", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 oral_history_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Interviewer"), md_nil_check(item.element_texts[16], "Item Type Metadata:Interviewee"), md_nil_check(item.element_texts[17], "Item Type Metadata:Location"), md_nil_check(item.element_texts[18], "Item Type Metadata:Transcription"), md_nil_check(item.element_texts[19], "Item Type Metadata:Original Format"),md_nil_check(item.element_texts[20], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[21], "Item Type Metadata:it Rate/Frequency"), md_nil_check(item.element_texts[22], "Item Type Metadata:Time Summary"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_text_items_csv(text_items, name)
  		if !text_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_text", "it_original_format", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 text_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Text"), md_nil_check(item.element_texts[16], "Item Type Metadata:Original Format"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_event_items_csv(event_items, name)
  		if !event_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_duration", "it_event_type", "it_participants", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 event_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[16], "Item Type Metadata:Event Type"), md_nil_check(item.element_texts[17], "Item Type Metadata:Participants"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_lesson_plan_items_csv(lesson_plan_items, name)
  		if !lesson_plan_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_duration", "it_standards", "it_objectives", "it_materials", "it_lesson_plan_text", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 lesson_plan_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Duration"), md_nil_check(item.element_texts[16], "Item Type Metadata:Standards"), md_nil_check(item.element_texts[17], "Item Type Metadata:Objectives"), md_nil_check(item.element_texts[18], "Item Type Metadata:Materials"), md_nil_check(item.element_texts[19], "Item Type Metadata:Lesson Plan Text"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_person_items_csv(person_items, name)
  		if !person_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_birth_date", "it_birthplace", "it_death_date", "it_occupation", "it_biographical_text", "it_bibliography", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 person_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Birth Date"), md_nil_check(item.element_texts[16], "Item Type Metadata:Birthplace"), md_nil_check(item.element_texts[17], "Item Type Metadata:Death Date"), md_nil_check(item.element_texts[18], "Item Type Metadata:Occupaton"), md_nil_check(item.element_texts[19], "Item Type Metadata:Biographical Text"), md_nil_check(item.element_texts[20], "Item Type Metadata:Bibliography"), collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_email_items_csv(email_items, name)
  		if !email_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_email_body", "it_subject_line", "it_from", "it_to", "it_cc", "it_bcc", "it_number_of_attachments", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 email_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Email Body"), md_nil_check(item.element_texts[16], "Item Type Metadata:Subject Line"), md_nil_check(item.element_texts[17], "Item Type Metadata:From"), md_nil_check(item.element_texts[18], "Item Type Metadata:To"), md_nil_check(item.element_texts[19], "Item Type Metadata:CC"), md_nil_check(item.element_texts[20], "Item Type Metadata:BCC"), md_nil_check(item.element_texts[21], "Item Type Metadata:Number of Attachments"), collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_website_items_csv(website_items, name)
  		if !website_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_local_url", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 website_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Local URL"), collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_hyperlink_items_csv(hyperlink_items, name)
  		if !hyperlink_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_url", "collection_reference", "itemtype_reference", "file_url", "tags", "omeka_url"]
			  	end
				 hyperlink_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:URL"), collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_image_items_csv(image_items, name)
  		if !image_items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_image_#{name}.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "it_original_format", "it_physical_dimensions", "collection_reference", "itemtype_reference", "file_url", "first_img", "tags", "omeka_url"]
			  	end
				 image_items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"), md_nil_check(item.element_texts[15], "Item Type Metadata:Original Format"), md_nil_check(item.element_texts[16], "Item Type Metadata:Physical Dimensions"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), get_first_url(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_items_csv(items, name)
  		if !items.empty?
			csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_#{name}_items.csv"
			@md_hash = Hash.new
			CSV.open(csv_file, 'ab') do |csv|
				file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
			  	if file.none?
			    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage", "collection_reference", "itemtype_reference", "file_url", "first_img", "tags", "omeka_url"]
			  	end
				 items.each do |item|
	    			csv << [item.id, title_nil_check(item.element_texts[0]), item.public, item.featured, md_nil_check(item.element_texts[1], "Dublin Core:Subject"), md_nil_check(item.element_texts[2], "Dublin Core:Description"), md_nil_check(item.element_texts[3], "Dublin Core:Creator"), md_nil_check(item.element_texts[4], "Dublin Core:Source"), md_nil_check(item.element_texts[5], "Dublin Core:Publisher"), md_nil_check(item.element_texts[6], "Dublin Core:Date"),md_nil_check(item.element_texts[7], "Dublin Core:Contributor"), md_nil_check(item.element_texts[8], "Dublin Core:Rights"), md_nil_check(item.element_texts[9], "Dublin Core:Relation"), md_nil_check(item.element_texts[10], "Dublin Core:Format"), md_nil_check(item.element_texts[11], "Dublin Core:Language"), md_nil_check(item.element_texts[12], "Dublin Core:Type"), md_nil_check(item.element_texts[13], "Dublin Core:Identifier"), md_nil_check(item.element_texts[14], "Dublin Core:Coverage"),collection_nil_check(item.collection), item_type_nil_check(item.item_type), url_nil_check(item.files), get_first_url(item.files), collect_tags(item.tags), item.url.gsub("api\/items", "items\/show")]
	    		end
	  		end
	  	end
  	end

  	def create_collections_csv(parsed_collections)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_collections.csv"
		@md_hash = Hash.new
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "title", "public", "featured", "dc_subject", "dc_desc", "dc_creator", "dc_source", "dc_publisher", "dc_date", "dc_contributor","dc_rights", "dc_relation", "dc_format", "dc_language", "dc_type", "dc_identifier", "dc_coverage"]
		  	end
			 parsed_collections.each do |collection|
    			csv << [collection.id, collection.element_texts[0].text, collection.public, collection.featured, md_nil_check(collection.element_texts[1], "Dublin Core:Subject"), md_nil_check(collection.element_texts[2], "Dublin Core:Description"), md_nil_check(collection.element_texts[3], "Dublin Core:Creator"), md_nil_check(collection.element_texts[4],"Dublin Core:Source"), md_nil_check(collection.element_texts[5], "Dublin Core:Publisher"), md_nil_check(collection.element_texts[6], "Dublin Core:Date"), md_nil_check(collection.element_texts[7], "Dublin Core:Contributor"), md_nil_check(collection.element_texts[8], "Dublin Core:Rights"), md_nil_check(collection.element_texts[9], "Dublin Core:Relation"), md_nil_check(collection.element_texts[10], "Dublin Core:Format"), md_nil_check(collection.element_texts[11], "Dublin Core:Language"), md_nil_check(collection.element_texts[12], "Dublin Core:Type"), md_nil_check(collection.element_texts[13], "Dublin Core:Identifier"), md_nil_check(collection.element_texts[14], "Dublin Core:Coverage")]
    		end
  		end
  	end

  	def create_pages_csv(parsed_pages)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_pages.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "title", "slug", "published", "text", "updated", "parent"]
		  	end
			 parsed_pages.each do |page|
			 	puts page.parent
			 	puts '------------'
    			csv << [page.id, page.title, page.slug, page.is_published, page.text, page.updated, basic_page_title(page.parent)]
    		end
  		end
  	end

  	def create_itemtypes_csv(parsed_pages)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_item_types.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "name", "description", "element_name1", "element_desc1", "element_name2", "element_desc2",  "element_name3", "element_desc3",  "element_name4", "element_desc4",  "element_name5", "element_desc5",  "element_name6", "element_desc6",  "element_name7", "element_desc7",  "element_name8", "element_desc8",  "element_name9", "element_desc9",  "element_name10", "element_desc10",  "element_name11", "element_desc11",  "element_name12", "element_desc12"]
		  	end
			 parsed_pages.each do |item_type|
			 	e_infos =[]
			 	item_type.elements.each do |e|
			 		e_infos << element_info(e.id)
	    		end
	    		csv << [item_type.id, item_type.name, item_type.description, element_name_nil_check(e_infos[0]), element_desc_nil_check(e_infos[0]), element_name_nil_check(e_infos[1]), element_desc_nil_check(e_infos[1]), element_name_nil_check(e_infos[2]), element_desc_nil_check(e_infos[2]), element_name_nil_check(e_infos[3]), element_desc_nil_check(e_infos[3]), element_name_nil_check(e_infos[4]), element_desc_nil_check(e_infos[4]), element_name_nil_check(e_infos[5]), element_desc_nil_check(e_infos[5]), element_name_nil_check(e_infos[6]), element_desc_nil_check(e_infos[6]), element_name_nil_check(e_infos[7]), element_desc_nil_check(e_infos[7]), element_name_nil_check(e_infos[8]), element_desc_nil_check(e_infos[8]), element_name_nil_check(e_infos[9]), element_desc_nil_check(e_infos[9]), element_name_nil_check(e_infos[10]), element_desc_nil_check(e_infos[10]), element_name_nil_check(e_infos[11]), element_desc_nil_check(e_infos[11])]
    		end
  		end
  	end

  	def create_exhibits_csv(parsed_exhibits)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibits.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "title", "slug", "description", "credits", "added", "updated", "public", "featured", "page_count", "exhibit_page_title"]
		  	end
			 parsed_exhibits.each do |pex|
    			csv << [pex.id, pex.title, pex.slug, pex.description, pex.credits, pex.added, pex.modified, pex.public, pex.featured, pex.pages.count, exhibit_page_title(pex.pages.url.split("=")[1])]
    		end
  		end
  	end

  	def create_exhibitpages_csv(exp_parsed)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibitpages.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "title", "slug", "order", "exhibit_id", "parent_title", "page_block_titles"]
		  	end
			 exp_parsed.each do |exp|
    			csv << [exp.id, exp.title, exp.slug, exp.order, exp.exhibit.id, page_block_parent(exp.parent), page_block_titles(exp.page_blocks)]
    		end
  		end
  	end

  	def create_exhibitpages_blocks_csv(exp_parsed)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibitpages_blocks.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["block_title", "page_id", "layout", "position", "gallery_position", "file_size", "caption_position", "text", "order", "attachment_titles", "attachment_items", "attachment_captions"]
		  	end
			 exp_parsed.each do |exp|
			 	exp.page_blocks.each do |block|
    				csv << ["#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibit_block_#{block.id}", block.page_id, block.layout, split_option_position(block.options), split_option_gallery(block.options), split_option_filesize(block.options), split_option_caption_position(block.options), block.text, block.order, attachment_titles(block.id, block.attachments), attachment_item(block.attachments), attachment_caption(block.attachments)]
    			end
    		end
  		end
  	end

  	def create_exhibitpages_block_items_csv(exp_parsed)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_exhibitpages_block_attachments.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["attachment_title", "attachment_item", "attachment_caption"]
		  	end
			 exp_parsed.each do |exp|
			 	exp.page_blocks.each do |block|
			 		block.attachments.each do |attachment|
    					csv << ["#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_epb#{block.id}_item#{attachment.id}", item_title(attachment['item']['id']), attachment['caption']]
    				end
    			end
    		end
  		end
  	end

  	def create_geolocation_csv(parsed_geolocations)
		csv_file = "#{self.site['title'].gsub(" ", "_").gsub(",", "").downcase}_geolocations.csv"
		CSV.open(csv_file, 'ab') do |csv|
			file = CSV.read(csv_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if file.none?
		    	csv << ["id", "url", "street", "country", "latitude", "longitude", "zoom_level", "map_type", "address", "item_id", "item_title"]
		    	#csv << ["id", "url", "street", "city", "state", "zip", "country", "latitude", "longitude", "zoom_level", "map_type", "address", "item_id", "item_title"]

		  	end
			 parsed_geolocations.each do |geolocation|
			 	get_address("#{geolocation.latitude},#{geolocation.longitude}")
    			csv << [geolocation.id, geolocation.url, @street, @country, geolocation.latitude, geolocation.longitude, geolocation.zoom_level, geolocation.map_type, geolocation.address, geolocation.item.id, item_title(geolocation.item.id)]
    			#csv << [geolocation.id, geolocation.url, @street, @city, @state, @zip, @country, geolocation.latitude, geolocation.longitude, geolocation.zoom_level, geolocation.map_type, geolocation.address, geolocation.item.id, item_title(geolocation.item.id)]

    		end
  		end
  	end

  	def get_address(coordinates)
  		address = Geocoder.address(coordinates)
  		address_array = address.split(",")
  		country = address_array.pop.strip
  		#postal = address_array.pop.strip
  		#@zip = postal.split(" ")[1]
  		#@state = postal.split(" ")[0]
  		#@city = address_array.pop.strip
  		@street = address_array.join(",")	
  		if country == "USA"
  			@country = "US"
  		else
  			@country = ISO3166::Country.find_country_by_name(country).alpha2
  		end
  		sleep(3)
  	end		



end


#omeka_call = OmekaExport.new("http://#{ARGV.first}/api", ARGV.last)
#omeka_call.instatiate_omeka_client
#omeka_call.items

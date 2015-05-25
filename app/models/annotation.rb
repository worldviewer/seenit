class Annotation < ActiveRecord::Base
	serialize :ranges, JSON
	serialize :tags, JSON
	serialize :permissions, JSON
end

module Cardboard
  class PagePart < ActiveRecord::Base
    # self.table_name = "cardboard_page_parts"

    has_many :fields, class_name: "Cardboard::Field", :dependent => :destroy, :autosave => true, :foreign_key => "page_part_id"
    has_many :subparts, class_name: "Cardboard::PagePart", :dependent => :destroy, :foreign_key => "parent_part_id", :validate => true

    belongs_to :parent, class_name: "Cardboard::PagePart",  :foreign_key => "parent_part_id"
    belongs_to :page

    attr_accessible :position, :allow_multiple, :label, :subparts_attributes, :fields_attributes
    accepts_nested_attributes_for :subparts, :allow_destroy => true, :reject_if => :all_blank
    accepts_nested_attributes_for :fields, :allow_destroy => true

    validates :identifier, uniqueness: {:case_sensitive => false, :scope => :page_id}, 
                           :format => {:with => /\A[a-z\_0-9]+\z/, :message => "Only downcase letters, numbers and underscores are allowed"}, 
                           :unless => :subpart?
    validates_associated :fields
    
    #gem
    include RankedModel
    ranks :subpart_position, :with_same => :parent_part_id, :column => :position
    ranks :part_position, :with_same => :page_id, :column => :position



    def subpart?
      return true if self.page_id.nil?
    end

    def repeatable?
       @parent_repeatable ||= self.parent ? self.parent[:repeatable] : super
    end

    def new_subpart
      return nil if !repeatable? || subpart?
      master = self.subparts.first
      subpart = master.dup
      for field in master.fields
        new_field = field.dup
        new_field.value = nil
        new_field.page_part_id = nil
        subpart.fields << new_field
      end
      return subpart
    end

    def attr(field)
      field = field.to_s
      @attr ||= {}
      @attr[field] ||= begin
        f = self.fields.where(identifier: field).first

        if Rails.env.development? && f.value.nil? 
         f.default #be careful for booleans here
        else
         f.value 
        end
      end
    end

  end
end

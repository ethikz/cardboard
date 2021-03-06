module Cardboard
  class Page < ActiveRecord::Base

    has_many :parts, class_name: "Cardboard::PagePart", :dependent => :destroy, :validate => true

    belongs_to :template, class_name: "Cardboard::Template"
      
    attr_accessor :parent_url, :is_root

    accepts_nested_attributes_for :parts, allow_destroy: true, :reject_if => :all_blank
    # TODO: allow destroy and allow all blank only if repeatable

    serialize :meta_seo, Hash
    serialize :slugs_backup, Array

    before_validation :default_values
    before_save :update_slugs_backup

    #gems
    acts_as_url :title, :url_attribute => :slug, :scope =>  :path, only_when_blank: true

    include RankedModel
    ranks :position, :with_same => :path

    #validations
    validates_associated :parts
    validates :title, :path, :template, presence:true
    validates :slug, uniqueness: { :case_sensitive => false, :scope => :path }, presence: true
    validates :identifier, uniqueness: {:case_sensitive => false}, :format => { :with => /\A[a-z\_0-9]+\z/,
                           :message => "Only downcase letters, numbers and underscores are allowed" }, presence: true
    #validate all seo keys are valid meta keys + title

    #scopes
    scope :preordered, -> {order("path ASC, position ASC, slug ASC")} 


    #class variables
    after_commit do
      Page.clear_arranged_pages
    end

    #overwritten setters/getters
    def slug=(value)
      # the user can overwrite the auto generated slug
      self[:slug] = value.present? ? value.to_url : nil
    end

    def is_root=(val)
      self.position_position = :first if val
    end

    def using_slug_backup?
      @using_slug_backup || false
    end

    def using_slug_backup=(value)
      @using_slug_backup = value
    end

    #class methods
    def self.find_by_url(full_url)
      return nil unless full_url
      path, slug = self.path_and_slug(full_url)
      page = self.where(path: path, slug: slug).first

      if slug && page.nil?
        #use arel instead of LIKE/ILIKE
        page = self.where(path: path).where(self.arel_table[:slugs_backup].matches("% #{slug}\n%")).first
        page.using_slug_backup = true if page
      end

      page
    end

    def self.root
      # Homepage is the highest position in the root path
      where(path: "/").rank(:position).first
    end
    def self.homepage; self.root; end

    def root?
      @root_id ||= Page.root.id
      @root_id == self.id
    end

    #instance methods

    def template_hash
      @template_hash ||= self.template.fields
    end

    # @page.get("slideshow.image1")
    # @page.get("slideshow").first.image1
    # @page.get("slideshow").each...

    # slideshow = @page.get("slideshow")
    # slideshow.field("image1")
    # slideshow.each{|p| p.field("image")}
    # slideshow.get("slide1")
    def get(field)
      f = field.split(".")
      parts = self.parts.where(identifier: f.first)

      if template_hash[f.first.to_sym][:repeatable]
        raise "Part is repeatable, expected each loop" unless f.size == 1 
        parts
      else
        part = parts.first
        return nil unless part
        f.size == 1 ? part : part.attr(f.last)
      end
    end


    # SEO
    # children inherit their parent's SEO settings (these can be overwritten)
    def seo
      @_seo ||= begin
        seo = self.meta_seo
        seo = self.parent.seo.merge(seo) if parent
        seo = Page.root.seo.merge(seo) unless root?
        seo
      end
    end
    
    def seo=(hash)
      # to hash is important here for strong parameters
      self.meta_seo = hash.to_hash
      @_seo = nil
    end
    
    def url
      return "/" if slug.blank? #|| self.root?
      "#{path}#{slug}/"
    end

    def split_path
      # path.sub(/^\//,'').split("/") # "/path/" => ["path"]
      path[1..-1].split("/")
    end

    def parent
      @parent ||= Cardboard::Page.find_by_url(path)
    end

    # Get all other pages
    def parent_url_options
      # @parent_url_options ||= begin
        Cardboard::Page.all.inject(["/"]) do |result, elm| 
          result << elm.url unless elm.id == self.id
          result
        end.sort
      # end
    end

    def parent_url
      return "/" if parent.nil?
      parent.url
    end

    def parent=(new_parent)
      return nil if new_parent && !new_parent.is_a?(Cardboard::Page) 
      self.path = new_parent ? new_parent.url : "/"
    end

    def parent_id=(new_parent_id)
      self.parent = Cardboard::Page.where(identifier: new_parent_id).first
    end

    def parent_url=(new_parent_url)
      self.parent = Cardboard::Page.find_by_url(new_parent_url)
    end

    def children
      Cardboard::Page.where(path: url)
    end

    def siblings
      Cardboard::Page.where("path = ? AND id != ?", path, id)
    end

    def depth
      # root is depth 0
      split_path.size
    end

    # Arrange array of nodes into a nested hash of the form 
    # {node => children}, where children = {} if the node has no children
    #
    # Example:
    # {#<Cardboard::Page => {
    #    #<Cardboard::Page => {}
    #    #<Cardboard::Page => {}
    #    #<Cardboard::Page => {#<Cardboard::Page => {}}
    # }}
    def self.arrange(root_page = nil)
      root_page ||= self.root
      return unless root_page
      # TODO: use root_page...

      Rails.cache.fetch("arranged_pages") do
        pages = self.preordered

        pages.inject(ActiveSupport::OrderedHash.new) do |ordered_hash, page|
          (["/"] + page.split_path).inject(ordered_hash) do |insertion_hash, subpath|
            
            insertion_hash.each do |parent, children|
              insertion_hash = children if subpath == parent.slug
            end
            insertion_hash
          end[page] = ActiveSupport::OrderedHash.new
          ordered_hash
        end
      end
    end 
    def self.clear_arranged_pages
      # clear cache when a page changes
      Rails.cache.delete("arranged_pages")
    end

  # def to_param
  #   "#{id}-#{slug}"
  # end  

  private
    def self.path_and_slug(full_url)
      *path, slug = full_url.sub(/^\//, '').split('/')
      [path.blank? ? '/' : "/#{path.join('/')}/", slug]
    end


    def update_slugs_backup
      return nil if !self.slug_changed? || self.slug_was.nil?
      self.slugs_backup |= [self.slug_was] #Yes, that's a single pipe...
    end

    def default_values
      self.path  ||= '/'
      self.title ||= self.identifier.parameterize("_")
    end
  end
end

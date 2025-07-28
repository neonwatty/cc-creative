class Document < ApplicationRecord
  belongs_to :user
  has_many :context_items, dependent: :destroy
  has_many :document_versions, dependent: :destroy
  has_many :sub_agents, dependent: :destroy
  
  # Rich text association for content
  has_rich_text :content
  
  # Serialize tags as JSON for SQLite compatibility
  serialize :tags, coder: JSON, type: Array
  
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :description, length: { maximum: 1000 }
  
  # Scopes for common queries
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :with_tag, ->(tag) { where("tags LIKE ?", "%#{tag}%") }
  
  # Ensure tags is always an array
  before_save :ensure_tags_array
  
  # Helper methods for tags
  def add_tag(tag)
    self.tags ||= []
    self.tags << tag unless self.tags.include?(tag)
  end
  
  def remove_tag(tag)
    self.tags ||= []
    self.tags.delete(tag)
  end
  
  def tag_list
    tags&.join(", ") || ""
  end
  
  def tag_list=(tag_string)
    return self.tags = [] if tag_string.nil?
    self.tags = tag_string.split(",").map(&:strip).reject(&:blank?).uniq
  end
  
  # Content manipulation methods
  def word_count
    # Count words in rich text content
    content.to_plain_text.split(/\s+/).size
  end
  
  def reading_time
    # Average reading speed is 200-250 words per minute
    (word_count / 200.0).ceil
  end
  
  def excerpt(length = 150)
    return "" if content.blank?
    content.to_plain_text.truncate(length, separator: " ")
  end
  
  # Duplicate document for a user
  def duplicate_for(user)
    new_document = user.documents.build(
      title: "#{title} (Copy)",
      description: description,
      tags: tags
    )
    
    # Duplicate the rich text content
    if content.present?
      new_document.content = content.to_plain_text
    end
    
    new_document
  end
  
  # Version management methods
  def next_version_number
    current_version_number.to_i + 1
  end

  def latest_version
    document_versions.order(:version_number).last
  end

  def version_at(version_number)
    document_versions.find_by(version_number: version_number)
  end

  def create_version(user, options = {})
    DocumentVersion.create_from_document(self, user, options)
  end

  def create_auto_version(user)
    create_version(user, is_auto_version: true)
  end

  def create_manual_version(user, version_name: nil, version_notes: nil)
    create_version(user, {
      is_auto_version: false,
      version_name: version_name,
      version_notes: version_notes
    })
  end

  # Check if document content has changed since last version
  def content_changed_since_last_version?
    return true if document_versions.empty?
    
    latest = latest_version
    return true if latest.nil?
    
    content.to_plain_text != latest.content_snapshot ||
      title != latest.title ||
      description != latest.description_snapshot ||
      (tags || []).sort != (latest.tags_snapshot || []).sort
  end

  # Track version metadata
  def version_info
    {
      current_version: current_version_number,
      total_versions: document_versions.count,
      latest_version_created: latest_version&.created_at,
      created: created_at,
      updated: updated_at,
      word_count: word_count
    }
  end
  
  private
  
  def ensure_tags_array
    self.tags ||= []
  end
end

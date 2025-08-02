class Document < ApplicationRecord
  belongs_to :user
  has_many :context_items, dependent: :destroy
  has_many :document_versions, dependent: :destroy
  has_many :sub_agents, dependent: :destroy
  has_many :claude_contexts, dependent: :destroy
  has_many :command_histories, dependent: :destroy
  has_many :command_audit_logs, dependent: :destroy

  # Rich text association for content
  has_rich_text :content

  # Serialize tags as JSON for SQLite compatibility
  serialize :tags, coder: JSON, type: Array

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }

  # Optimized scopes for common queries
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :with_tag, ->(tag) { where("tags LIKE ?", "%#{tag}%") }
  scope :active_in_period, ->(period) { where("updated_at > ?", period.ago) }
  scope :with_content, -> { joins(:rich_text_content) }
  scope :popular, -> { left_joins(:context_items).group(:id).order("COUNT(context_items.id) DESC") }
  
  # Performance-optimized scopes
  scope :recent_with_minimal_data, -> { select(:id, :title, :user_id, :created_at, :updated_at).recent }
  scope :user_documents_summary, ->(user) {
    by_user(user)
      .select(:id, :title, :description, :created_at, :updated_at, :current_version_number)
      .includes(:user)
  }

  # Ensure tags is always an array
  before_save :ensure_tags_array
  
  # Cache invalidation callbacks
  after_update :invalidate_content_caches
  after_destroy :invalidate_content_caches

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

  # Content manipulation methods with caching
  def word_count
    Rails.cache.fetch("document_#{id}_word_count", expires_in: 1.hour) do
      content&.to_plain_text&.split(/\s+/)&.size || 0
    end
  end

  def reading_time
    # Average reading speed is 200-250 words per minute
    (word_count / 200.0).ceil
  end

  def excerpt(length = 150)
    return "" if content.blank?
    
    Rails.cache.fetch("document_#{id}_excerpt_#{length}", expires_in: 1.hour) do
      content.to_plain_text.truncate(length, separator: " ")
    end
  end
  
  # Optimized content retrieval
  def content_plain_text
    @content_plain_text ||= content&.to_plain_text || ""
  end

  def content_for_search
    Rails.cache.fetch("document_#{id}_search_content", expires_in: 2.hours) do
      [title, description, content_plain_text].compact.join(" ").strip
    end
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

  # Content statistics for caching
  def content_statistics
    {
      word_count: word_count,
      reading_time: reading_time,
      character_count: content_plain_text.length,
      paragraph_count: content_plain_text.split(/\n\s*\n/).count,
      last_modified: updated_at
    }
  end

  # Collaboration summary for caching
  def collaboration_summary
    # Placeholder for collaboration data
    # TODO: Implement when collaboration sessions are added
    {
      active_collaborators: 0,
      recent_changes: 0,
      last_collaboration: nil
    }
  end

  private

  def ensure_tags_array
    self.tags ||= []
  end
  
  def invalidate_content_caches
    cache_keys = [
      "document_#{id}_word_count",
      "document_#{id}_search_content"
    ]
    
    # Invalidate excerpt caches for common lengths
    [100, 150, 200, 300].each do |length|
      cache_keys << "document_#{id}_excerpt_#{length}"
    end
    
    cache_keys.each { |key| Rails.cache.delete(key) }
  end
end

class DocumentVersion < ApplicationRecord
  belongs_to :document
  belongs_to :created_by_user, class_name: "User"

  # JSON column handles serialization automatically in Rails 8

  validates :version_number, presence: true, uniqueness: { scope: :document_id }
  validates :title, presence: true, length: { maximum: 255 }
  validates :content_snapshot, presence: true
  validates :word_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes for filtering
  scope :auto_versions, -> { where(is_auto_version: true) }
  scope :manual_versions, -> { where(is_auto_version: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_document, ->(document) { where(document: document) }
  scope :by_version_number, -> { order(:version_number) }

  # Ensure tags_snapshot is always an array
  before_save :ensure_tags_snapshot_array

  # Class method to create version from document
  def self.create_from_document(document, user, options = {})
    version = new(
      document: document,
      version_number: document.next_version_number,
      title: document.title,
      content_snapshot: document.content.to_plain_text,
      description_snapshot: document.description,
      tags_snapshot: document.tags || [],
      version_name: options[:version_name],
      version_notes: options[:version_notes],
      created_by_user: user,
      is_auto_version: options[:is_auto_version] || false,
      word_count: document.word_count
    )
    
    if version.save
      document.update(current_version_number: version.version_number)
    end
    
    version
  end

  # Content comparison methods
  def content_changed_from_previous?
    previous_version = document.document_versions
                              .where("version_number < ?", version_number)
                              .order(:version_number)
                              .last
    
    return true if previous_version.nil?
    
    content_snapshot != previous_version.content_snapshot
  end

  def content_diff_from_previous
    previous_version = document.document_versions
                              .where("version_number < ?", version_number)
                              .order(:version_number)
                              .last
    
    return nil if previous_version.nil?
    
    {
      previous_content: previous_version.content_snapshot,
      current_content: content_snapshot,
      previous_word_count: previous_version.word_count,
      current_word_count: word_count,
      word_count_diff: word_count - previous_version.word_count
    }
  end

  def tags_changed_from_previous?
    previous_version = document.document_versions
                              .where("version_number < ?", version_number)
                              .order(:version_number)
                              .last
    
    return true if previous_version.nil?
    
    tags_snapshot.sort != previous_version.tags_snapshot.sort
  end

  # Helper methods
  def version_type
    is_auto_version? ? "Auto" : "Manual"
  end

  def display_name
    version_name.present? ? version_name : "Version #{version_number}"
  end

  def short_content_preview(length = 100)
    content_snapshot.truncate(length, separator: " ")
  end

  # JSON serialization for API responses
  def as_json(options = {})
    super(options.merge(
      methods: [:version_type, :display_name],
      except: [:content_snapshot],
      include: {
        created_by_user: { only: [:id, :name, :email_address] }
      }
    ))
  end

  def to_json_with_content(options = {})
    as_json(options.merge(
      methods: [:version_type, :display_name, :short_content_preview],
      include: {
        created_by_user: { only: [:id, :name, :email_address] }
      }
    ))
  end

  private

  def ensure_tags_snapshot_array
    self.tags_snapshot ||= []
  end
end

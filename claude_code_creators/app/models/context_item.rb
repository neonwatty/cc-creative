class ContextItem < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :content, presence: true
  validates :item_type, presence: true, inclusion: { in: %w[snippet draft version] }
  validates :title, presence: true, length: { maximum: 255 }
  
  # Callbacks to maintain search content
  before_save :update_search_content

  scope :snippets, -> { where(item_type: 'snippet') }
  scope :drafts, -> { where(item_type: 'draft') }
  scope :versions, -> { where(item_type: 'version') }
  scope :recent, -> { order(created_at: :desc) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
  
  # Search scopes
  scope :search, ->(query) { 
    return all if query.blank?
    
    # SQLite-compatible search using LIKE
    sanitized_query = "%#{sanitize_sql_like(query.downcase)}%"
    where("LOWER(search_content) LIKE ?", sanitized_query)
  }
  
  scope :by_type, ->(type) {
    return all if type.blank?
    where(item_type: type)
  }
  
  scope :by_date_range, ->(start_date, end_date) {
    return all if start_date.blank? && end_date.blank?
    
    scope = all
    scope = scope.where('created_at >= ?', start_date) if start_date.present?
    scope = scope.where('created_at <= ?', end_date) if end_date.present?
    scope
  }
  
  # Combined search with filters
  scope :filtered_search, ->(query: nil, item_type: nil, date_from: nil, date_to: nil) {
    search(query)
      .by_type(item_type)
      .by_date_range(date_from, date_to)
  }
  
  # Search result methods
  def self.search_with_highlights(query)
    return [] if query.blank?
    
    results = search(query).includes(:document, :user)
    
    # Add highlights to results
    results.map do |item|
      {
        item: item,
        highlights: item.search_highlights(query)
      }
    end
  end
  
  def search_highlights(query)
    return {} if query.blank?
    
    # Simple highlighting for SQLite
    highlighted_title = highlight_text(title, query)
    highlighted_content = highlight_text(content, query, max_length: 200)
    
    {
      title: highlighted_title,
      content: highlighted_content
    }
  end
  
  # Simple text highlighting
  def highlight_text(text, query, max_length: nil)
    return text if query.blank?
    
    # Truncate if needed
    text = text.truncate(max_length) if max_length && text.length > max_length
    
    # Case-insensitive highlighting
    text.gsub(/(#{Regexp.escape(query)})/i, '<mark>\1</mark>')
  end
  
  before_create :set_position

  def snippet?
    item_type == 'snippet'
  end

  def draft?
    item_type == 'draft'
  end

  def version?
    item_type == 'version'
  end
  
  private
  
  def set_position
    max_position = document.context_items.where(item_type: item_type).maximum(:position) || 0
    self.position = max_position + 1
  end
  
  def update_search_content
    self.search_content = "#{title} #{content} #{item_type}".downcase
  end
end

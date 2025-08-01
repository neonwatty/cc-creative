module ApplicationHelper
  def format_date(date)
    return "" if date.nil?
    
    if date.today?
      "Today at #{date.strftime('%l:%M %p').strip}"
    elsif date.yesterday?
      "Yesterday at #{date.strftime('%l:%M %p').strip}"
    elsif date >= 7.days.ago
      date.strftime('%A at %l:%M %p').strip
    else
      date.strftime('%B %d, %Y')
    end
  end

  def truncate_content(content, length = 100)
    return "" if content.blank?
    
    # Handle both plain text and rich text content
    plain_text = if content.respond_to?(:to_plain_text)
                   content.to_plain_text
                 else
                   content.to_s
                 end
    
    plain_text.truncate(length, separator: " ")
  end
end

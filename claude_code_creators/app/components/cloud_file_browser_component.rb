# frozen_string_literal: true

class CloudFileBrowserComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(integration:, files: [], view_mode: "grid", pagination: nil, search_query: nil, filter: "all")
    @integration = integration
    @files = files
    @view_mode = view_mode
    @pagination = pagination
    @search_query = search_query
    @filter = filter
  end

  private

  attr_reader :integration, :files, :view_mode, :pagination, :search_query, :filter

  def controller_data
    {
      controller: "cloud-file-browser",
      cloud_file_browser_integration_id_value: integration.id,
      cloud_file_browser_view_mode_value: view_mode,
      cloud_file_browser_filter_value: filter,
      cloud_file_browser_search_query_value: search_query
    }
  end

  def browser_css_classes
    classes = [ "cloud-file-browser" ]
    classes << "cloud-file-browser--#{view_mode}"
    classes << "cloud-file-browser--loading" if files.empty?
    classes.join(" ")
  end

  def view_toggle_options
    [
      { mode: "grid", icon: "grid", label: "Grid View" },
      { mode: "list", icon: "list", label: "List View" }
    ]
  end

  def sort_options
    [
      { value: "name:asc", label: "Name A-Z" },
      { value: "name:desc", label: "Name Z-A" },
      { value: "date:desc", label: "Newest First" },
      { value: "date:asc", label: "Oldest First" },
      { value: "size:desc", label: "Largest First" },
      { value: "size:asc", label: "Smallest First" },
      { value: "type:asc", label: "Type A-Z" }
    ]
  end

  def filter_options
    [
      { value: "all", label: "All Files", count: files.count },
      { value: "importable", label: "Importable", count: files.select(&:importable?).count },
      { value: "synced", label: "Synced", count: files.select(&:synced?).count },
      { value: "unsynced", label: "Needs Sync", count: files.reject(&:synced?).count }
    ]
  end

  def has_files?
    files.any?
  end

  def empty_state_message
    if search_query.present?
      "No files found matching \"#{search_query}\""
    elsif filter != "all"
      "No #{filter} files found"
    else
      "No files found. Click \"Sync\" to load files from #{integration.provider_name}."
    end
  end

  def empty_state_actions
    actions = []

    if search_query.blank? && filter == "all"
      actions << {
        text: "Sync #{integration.provider_name}",
        action: "click->cloud-file-browser#syncFiles",
        class: "btn btn--primary"
      }
    end

    if search_query.present?
      actions << {
        text: "Clear Search",
        action: "click->cloud-file-browser#clearSearch",
        class: "btn btn--secondary"
      }
    end

    actions
  end

  def selected_count_display
    "0 selected"
  end



  def render_pagination
    return "" unless pagination

    # Simple pagination rendering - could be enhanced
    content_tag :div, class: "pagination" do
      "Page #{pagination[:current_page]} of #{pagination[:total_pages]}"
    end
  end

  def batch_actions
    [
      {
        action: "batchImport",
        icon: "import",
        text: "Import Selected",
        class: "btn btn--primary btn--sm"
      },
      {
        action: "batchDownload",
        icon: "download",
        text: "Download Selected",
        class: "btn btn--secondary btn--sm"
      }
    ]
  end

  def file_list_container_class
    case view_mode
    when "grid"
      "file-list file-list--grid"
    when "list"
      "file-list file-list--table"
    else
      "file-list"
    end
  end

  def render_file_list
    if view_mode == "list"
      render_table_view
    else
      render_grid_view
    end
  end

  private

  def render_grid_view
    content_tag :div, class: "file-grid" do
      files.map { |file| render(CloudFileItemComponent.new(file: file, view_mode: "grid")) }.join.html_safe
    end
  end

  def render_table_view
    content_tag :table, class: "file-table" do
      concat(render_table_header)
      concat(render_table_body)
    end
  end

  def render_table_header
    content_tag :thead do
      content_tag :tr do
        concat(content_tag(:th, content_tag(:input, "", type: "checkbox", data: { action: "change->cloud-file-browser#selectAll" }), class: "file-table__checkbox"))
        concat(content_tag(:th, "Name", class: "file-table__name"))
        concat(content_tag(:th, "Size", class: "file-table__size"))
        concat(content_tag(:th, "Modified", class: "file-table__date"))
        concat(content_tag(:th, "Status", class: "file-table__status"))
        concat(content_tag(:th, "Actions", class: "file-table__actions"))
      end
    end
  end

  def render_table_body
    content_tag :tbody do
      files.map { |file| render(CloudFileItemComponent.new(file: file, view_mode: "list")) }.join.html_safe
    end
  end

  def pagination_info
    return nil unless pagination

    {
      current_page: pagination[:current_page],
      total_pages: pagination[:total_pages],
      total_count: pagination[:total_count],
      per_page: pagination[:per_page]
    }
  end

  def render_pagination
    return unless pagination && pagination[:total_pages] > 1

    content_tag :div, class: "pagination-container" do
      concat(pagination_info_text)
      concat(pagination_controls)
    end
  end

  def pagination_info_text
    return unless pagination

    start_item = ((pagination[:current_page] - 1) * pagination[:per_page]) + 1
    end_item = [ start_item + pagination[:per_page] - 1, pagination[:total_count] ].min

    content_tag :div, class: "pagination-info" do
      "Showing #{start_item}-#{end_item} of #{pagination[:total_count]} files"
    end
  end

  def pagination_controls
    content_tag :div, class: "pagination-controls" do
      concat(prev_page_button)
      concat(page_numbers)
      concat(next_page_button)
    end
  end

  def prev_page_button
    return unless pagination && pagination[:prev_page]

    content_tag :button,
                class: "pagination__btn",
                data: { action: "click->cloud-file-browser#changePage", page: pagination[:prev_page] } do
      "← Previous"
    end
  end

  def next_page_button
    return unless pagination && pagination[:next_page]

    content_tag :button,
                class: "pagination__btn",
                data: { action: "click->cloud-file-browser#changePage", page: pagination[:next_page] } do
      "Next →"
    end
  end

  def page_numbers
    return unless pagination

    content_tag :span, class: "pagination__info" do
      "Page #{pagination[:current_page]} of #{pagination[:total_pages]}"
    end
  end

  def sync_status_text
    if integration.cloud_files.any?
      last_sync = integration.cloud_files.maximum(:last_synced_at)
      if last_sync
        "Last synced #{time_ago_in_words(last_sync)} ago"
      else
        "Never synced"
      end
    else
      "No files synced"
    end
  end

  def total_file_size
    return 0 unless files.any?

    files.sum { |file| file.size || 0 }
  end

  def formatted_total_size
    helpers.number_to_human_size(total_file_size)
  end
end

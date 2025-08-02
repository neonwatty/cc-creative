# frozen_string_literal: true

class CloudFileItemComponent < ViewComponent::Base
  def initialize(file:, view_mode: "grid", selectable: true, show_actions: true)
    @file = file
    @view_mode = view_mode
    @selectable = selectable
    @show_actions = show_actions
  end

  private

  attr_reader :file, :view_mode, :selectable, :show_actions

  def item_css_classes
    classes = [ "file-item", "file-item--#{view_mode}" ]
    classes << "file-item--importable" if file.importable?
    classes << "file-item--synced" if file.synced?
    classes << "file-item--#{file_type}"
    classes.join(" ")
  end

  def file_type
    return "document" if file.google_doc?
    return "pdf" if file.pdf?
    return "text" if file.text?
    return "word" if file.word_doc?
    return "image" if file.mime_type&.start_with?("image/")
    return "video" if file.mime_type&.start_with?("video/")
    return "audio" if file.mime_type&.start_with?("audio/")
    "file"
  end

  def file_icon_class
    "file-icon file-icon--#{file_type}"
  end

  def file_size_display
    file.human_size
  end

  def file_date_display
    return "Unknown" unless file.updated_at

    if view_mode == "grid"
      time_ago_in_words(file.updated_at) + " ago"
    else
      file.updated_at.strftime("%b %d, %Y at %l:%M %p")
    end
  end

  def sync_status_badge
    if file.synced?
      { class: "badge badge--synced", text: "Synced" }
    else
      { class: "badge badge--needs-sync", text: "Needs Sync" }
    end
  end

  def importable_badge
    return nil unless file.importable?
    { class: "badge badge--importable", text: "Importable" }
  end

  def file_badges
    badges = []
    badges << sync_status_badge
    badges << importable_badge if importable_badge
    badges.compact
  end

  def item_data_attributes
    {
      'file-id': file.id,
      action: selectable ? "click->cloud-file-browser#toggleFileSelection" : nil
    }.compact
  end

  def checkbox_data_attributes
    {
      'file-id': file.id,
      action: "change->cloud-file-browser#toggleFileSelection"
    }
  end

  def preview_action_data
    {
      action: "click->cloud-file-browser#previewFile",
      'file-id': file.id
    }
  end

  def import_action_data
    {
      action: "click->cloud-file-browser#importFile",
      'file-id': file.id
    }
  end

  def download_action_data
    {
      action: "click->cloud-file-browser#downloadFile",
      'file-id': file.id
    }
  end

  def file_actions
    actions = []

    if file.importable?
      actions << {
        text: "Import",
        icon: "import",
        class: "btn btn--primary btn--sm",
        data: import_action_data,
        title: "Import this file as a document"
      }
    end

    actions << {
      text: "Preview",
      icon: "eye",
      class: "btn btn--secondary btn--sm",
      data: preview_action_data,
      title: "Preview file contents"
    }

    if file.provider_url
      actions << {
        text: "Open",
        icon: "external-link",
        class: "btn btn--secondary btn--sm",
        href: file.provider_url,
        target: "_blank",
        title: "Open in #{file.cloud_integration.provider_name}"
      }
    end

    actions
  end

  def render_grid_item
    content_tag :div, class: item_css_classes, data: item_data_attributes do
      concat(render_file_thumbnail)
      concat(render_file_info)
      concat(render_file_actions) if show_actions
    end
  end

  def render_list_item
    content_tag :tr, class: item_css_classes, data: { 'file-id': file.id } do
      concat(render_checkbox_cell) if selectable
      concat(render_name_cell)
      concat(render_size_cell)
      concat(render_date_cell)
      concat(render_status_cell)
      concat(render_actions_cell) if show_actions
    end
  end

  def render_file_thumbnail
    content_tag :div, class: "file-item__thumbnail" do
      content_tag :i, "", class: file_icon_class, data: { type: file.mime_type }
    end
  end

  def render_file_info
    content_tag :div, class: "file-item__info" do
      concat(content_tag(:h3, file.name, class: "file-item__name", title: file.name))
      concat(content_tag(:p, "#{file_size_display} • #{file_date_display}", class: "file-item__meta"))
      concat(render_file_badges)
    end
  end

  def render_file_badges
    return unless file_badges.any?

    content_tag :div, class: "file-item__badges" do
      file_badges.map do |badge|
        content_tag(:span, badge[:text], class: badge[:class])
      end.join.html_safe
    end
  end

  def render_file_actions
    return unless show_actions

    content_tag :div, class: "file-item__actions" do
      if selectable
        concat(content_tag(:input, "", type: "checkbox", class: "file-checkbox", data: checkbox_data_attributes))
      end

      file_actions.each do |action|
        if action[:href]
          concat(link_to(action[:href], class: action[:class], target: action[:target], title: action[:title]) do
            content_tag(:i, "", class: "icon icon--#{action[:icon]}") + " " + action[:text]
          end)
        else
          concat(content_tag(:button, class: action[:class], data: action[:data], title: action[:title]) do
            content_tag(:i, "", class: "icon icon--#{action[:icon]}") + " " + action[:text]
          end)
        end
      end
    end
  end

  # Table view cells
  def render_checkbox_cell
    content_tag :td, class: "file-item__checkbox" do
      content_tag :input, "", type: "checkbox", class: "file-checkbox", data: checkbox_data_attributes
    end
  end

  def render_name_cell
    content_tag :td, class: "file-item__name" do
      content_tag :div, class: "file-name-wrapper" do
        concat(content_tag(:i, "", class: file_icon_class, data: { type: file.mime_type }))
        concat(content_tag(:span, file.name, class: "file-name", title: file.name))
      end
    end
  end

  def render_size_cell
    content_tag :td, file_size_display, class: "file-item__size"
  end

  def render_date_cell
    content_tag :td, file_date_display, class: "file-item__date"
  end

  def render_status_cell
    content_tag :td, class: "file-item__status" do
      file_badges.map do |badge|
        content_tag(:span, badge[:text], class: badge[:class])
      end.join(" ").html_safe
    end
  end

  def render_actions_cell
    content_tag :td, class: "file-item__actions" do
      file_actions.each do |action|
        if action[:href]
          concat(link_to(action[:href], class: action[:class], target: action[:target], title: action[:title]) do
            content_tag(:i, "", class: "icon icon--#{action[:icon]}") + " " + action[:text]
          end)
        else
          concat(content_tag(:button, class: action[:class], data: action[:data], title: action[:title]) do
            content_tag(:i, "", class: "icon icon--#{action[:icon]}") + " " + action[:text]
          end)
        end
      end
    end
  end

  def file_metadata
    {
      id: file.id,
      name: file.name,
      size: file.size,
      mime_type: file.mime_type,
      importable: file.importable?,
      synced: file.synced?,
      provider: file.provider,
      created_at: file.created_at,
      updated_at: file.updated_at
    }
  end

  def provider_icon
    case file.provider
    when "google_drive"
      "google-drive"
    when "dropbox"
      "dropbox"
    when "notion"
      "notion"
    else
      "cloud"
    end
  end
end

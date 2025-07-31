require "test_helper"

class CloudFileBrowserComponentTest < ViewComponent::TestCase
  setup do
    @integration = cloud_integrations(:one)
    @files = []
  end

  test "renders with default parameters" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_selector ".cloud-file-browser"
    assert_selector ".cloud-file-browser--grid"
    assert_selector ".cloud-file-browser--loading"
    assert_selector "[data-controller='cloud-file-browser']"
    assert_selector "[data-cloud-file-browser-integration-id-value='#{@integration.id}']"
    assert_selector "[data-cloud-file-browser-view-mode-value='grid']"
    assert_selector "[data-cloud-file-browser-filter-value='all']"
  end

  test "renders grid view mode" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      view_mode: 'grid'
    ))
    
    assert_selector ".cloud-file-browser--grid"
    assert_selector ".file-list--grid"
    assert_selector ".file-grid"
  end

  test "renders list view mode" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      view_mode: 'list'
    ))
    
    assert_selector ".cloud-file-browser--list"
    assert_selector ".file-list--table"
    assert_selector "table.file-table"
    assert_selector "th", text: "Name"
    assert_selector "th", text: "Size"
    assert_selector "th", text: "Modified"
    assert_selector "th", text: "Status"
    assert_selector "th", text: "Actions"
  end

  test "renders search query" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      search_query: 'test query'
    ))
    
    assert_selector "[data-cloud-file-browser-search-query-value='test query']"
  end

  test "renders filter value" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      filter: 'synced'
    ))
    
    assert_selector "[data-cloud-file-browser-filter-value='synced']"
  end

  test "renders empty state with no files" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_text "No files found. Click \"Sync\" to load files from #{@integration.provider_name}."
    assert_selector "button", text: "Sync #{@integration.provider_name}"
  end

  test "renders empty state with search query" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      search_query: 'missing file'
    ))
    
    assert_text 'No files found matching "missing file"'
    assert_selector "button", text: "Clear Search"
  end

  test "renders empty state with filter" do
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      filter: 'synced'
    ))
    
    assert_text "No synced files found"
  end

  test "renders view toggle options" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_selector "[data-action='click->cloud-file-browser#changeView'][data-view='grid']"
    assert_selector "[data-action='click->cloud-file-browser#changeView'][data-view='list']"
  end

  test "renders sort dropdown" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_selector "select[data-action='change->cloud-file-browser#sortFiles']"
    assert_selector "option[value='name:asc']", text: "Name A-Z"
    assert_selector "option[value='date:desc']", text: "Newest First"
    assert_selector "option[value='size:desc']", text: "Largest First"
  end

  test "renders filter tabs" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_selector "[data-action='click->cloud-file-browser#changeFilter'][data-filter='all']"
    assert_selector "[data-action='click->cloud-file-browser#changeFilter'][data-filter='importable']"
    assert_selector "[data-action='click->cloud-file-browser#changeFilter'][data-filter='synced']"
    assert_selector "[data-action='click->cloud-file-browser#changeFilter'][data-filter='unsynced']"
  end

  test "renders batch actions when files selected" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_selector "[data-action='click->cloud-file-browser#batchImport']", text: "Import Selected"
    assert_selector "[data-action='click->cloud-file-browser#batchDownload']", text: "Download Selected"
  end

  test "renders sync status" do
    rendered = render_inline(CloudFileBrowserComponent.new(integration: @integration))
    
    assert_text "No files synced"
  end

  test "renders pagination controls" do
    pagination = {
      current_page: 2,
      total_pages: 5,
      total_count: 100,
      per_page: 20,
      prev_page: 1,
      next_page: 3
    }
    
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      pagination: pagination
    ))
    
    assert_text "Showing 21-40 of 100 files"
    assert_text "Page 2 of 5"
    assert_selector "button", text: "← Previous"
    assert_selector "button", text: "Next →"
  end

  test "does not render pagination for single page" do
    pagination = {
      current_page: 1,
      total_pages: 1,
      total_count: 10,
      per_page: 20
    }
    
    rendered = render_inline(CloudFileBrowserComponent.new(
      integration: @integration,
      pagination: pagination
    ))
    
    refute_selector ".pagination-container"
  end
end
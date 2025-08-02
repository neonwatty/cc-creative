require "test_helper"

class CloudFileItemComponentTest < ViewComponent::TestCase
  setup do
    @cloud_file = cloud_files(:one)
  end

  test "renders grid view by default" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector ".file-item"
    assert_selector ".file-item--grid"
    assert_selector ".file-item--text" # text/plain is a text file
    assert_selector ".file-item__thumbnail"
    assert_selector ".file-item__info"
    assert_selector ".file-item__actions"
  end

  test "renders list view" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, view_mode: "list"))

    assert_selector "tr.file-item"
    assert_selector ".file-item--list"
    assert_selector ".file-item__name"
    assert_selector ".file-item__size"
    assert_selector ".file-item__date"
    assert_selector ".file-item__status"
    assert_selector ".file-item__actions"
  end

  test "renders file name" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_text @cloud_file.name
  end

  test "renders file size" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_text @cloud_file.human_size
  end

  test "renders sync status badge" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    # CloudFile likely has a synced? method
    if @cloud_file.synced?
      assert_selector ".badge--synced", text: "Synced"
    else
      assert_selector ".badge--needs-sync", text: "Needs Sync"
    end
  end

  test "renders importable badge when applicable" do
    # Assuming text files are importable
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    if @cloud_file.importable?
      assert_selector ".badge--importable", text: "Importable"
    end
  end

  test "renders checkbox when selectable" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, selectable: true))

    assert_selector "input[type='checkbox'].file-checkbox"
    assert_selector "[data-file-id='#{@cloud_file.id}']"
  end

  test "does not render checkbox when not selectable" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, selectable: false))

    refute_selector "input[type='checkbox'].file-checkbox"
  end

  test "renders actions when show_actions is true" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, show_actions: true))

    assert_selector ".file-item__actions"
    assert_selector "button", text: "Preview"
  end

  test "does not render actions when show_actions is false" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, show_actions: false))

    refute_selector ".file-item__actions"
  end

  test "renders import action for importable files" do
    # Mock the file as importable
    @cloud_file.stubs(:importable?).returns(true)

    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector "button", text: "Import"
    assert_selector "[data-action='click->cloud-file-browser#importFile']"
  end

  test "renders preview action" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector "button", text: "Preview"
    assert_selector "[data-action='click->cloud-file-browser#previewFile']"
  end

  test "renders open action when provider_url exists" do
    @cloud_file.stubs(:provider_url).returns("https://drive.google.com/file/123")

    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector "a[href='https://drive.google.com/file/123'][target='_blank']", text: "Open"
  end

  test "applies correct file type class for documents" do
    @cloud_file.stubs(:google_doc?).returns(true)

    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector ".file-item--document"
    assert_selector ".file-icon--document"
  end

  test "applies correct file type class for PDFs" do
    @cloud_file.stubs(:pdf?).returns(true)

    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector ".file-item--pdf"
    assert_selector ".file-icon--pdf"
  end

  test "applies correct file type class for images" do
    @cloud_file.stubs(:mime_type).returns("image/jpeg")

    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector ".file-item--image"
    assert_selector ".file-icon--image"
  end

  test "renders correct data attributes" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file))

    assert_selector "[data-file-id='#{@cloud_file.id}']"
    assert_selector "[data-action='click->cloud-file-browser#toggleFileSelection']"
  end

  test "renders table cells in list view" do
    rendered = render_inline(CloudFileItemComponent.new(file: @cloud_file, view_mode: "list"))

    assert_selector "td.file-item__checkbox input[type='checkbox']"
    assert_selector "td.file-item__name"
    assert_selector "td.file-item__size"
    assert_selector "td.file-item__date"
    assert_selector "td.file-item__status"
    assert_selector "td.file-item__actions"
  end
end

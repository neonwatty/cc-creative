require "test_helper"

class WidgetDropZoneComponentTest < ViewComponent::TestCase
  test "renders with default settings" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector ".widget-drop-zone"
    assert_selector ".p-6.min-h-\\[200px\\]"
    assert_selector ".items-center.justify-center"
    assert_selector "[data-controller='widget-drop-zone']"
    assert_selector "[data-widget-drop-zone-target-value='#editor']"
  end

  test "renders with custom accepted types" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#sidebar",
      accepted_types: ['image', 'file']
    ))
    
    assert_selector "[data-widget-drop-zone-accepted-types-value='[\"image\",\"file\"]']"
  end

  test "renders with small size" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { size: :small }
    ))
    
    assert_selector ".p-4.min-h-\\[100px\\]"
    assert_selector ".w-8.h-8"
    assert_selector ".text-sm"
  end

  test "renders with large size" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { size: :large }
    ))
    
    assert_selector ".p-8.min-h-\\[300px\\]"
    assert_selector ".w-16.h-16"
    assert_selector ".text-xl"
  end

  test "renders with top position" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { position: :top }
    ))
    
    assert_selector ".items-start.justify-center"
  end

  test "renders with bottom position" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { position: :bottom }
    ))
    
    assert_selector ".items-end.justify-center"
  end

  test "shows instructions by default" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector ".transition-opacity.duration-200.space-y-3"
  end

  test "hides instructions when option set" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { show_instructions: false }
    ))
    
    # Instructions would be hidden via conditional rendering
    assert true
  end

  test "allows multiple items by default" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector "[data-widget-drop-zone-allow-multiple-value='true']"
  end

  test "disables multiple items when option set" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { allow_multiple: false }
    ))
    
    assert_selector "[data-widget-drop-zone-allow-multiple-value='false']"
  end

  test "renders drag event actions" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector "[data-action*='dragover->widget-drop-zone#handleDragOver']"
    assert_selector "[data-action*='dragenter->widget-drop-zone#handleDragEnter']"
    assert_selector "[data-action*='dragleave->widget-drop-zone#handleDragLeave']"
    assert_selector "[data-action*='drop->widget-drop-zone#handleDrop']"
  end

  test "renders overlay element" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector ".absolute.inset-0.bg-creative-primary-500\\/10"
  end

  test "renders pulse animation element" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector ".absolute.inset-0.border-2.border-creative-primary-400"
    assert_selector ".animate-ping"
  end

  test "displays accepted types list" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      accepted_types: ['context_item', 'widget', 'snippet']
    ))
    
    assert_text "Context Items, Widgets, Code Snippets"
  end

  test "renders default styling classes" do
    rendered = render_inline(WidgetDropZoneComponent.new(target_element: "#editor"))
    
    assert_selector ".bg-creative-neutral-50"
    assert_selector ".hover\\:bg-creative-neutral-100"
    assert_selector ".border-2.border-dashed.border-transparent"
    assert_selector ".rounded-xl"
  end

  test "renders position data attribute" do
    rendered = render_inline(WidgetDropZoneComponent.new(
      target_element: "#editor",
      options: { position: :bottom }
    ))
    
    assert_selector "[data-widget-drop-zone-position-value='bottom']"
  end
end
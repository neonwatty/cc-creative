require "test_helper"

class ThemeToggleComponentTest < ViewComponent::TestCase
  test "renders with default variant and size" do
    rendered = render_inline(ThemeToggleComponent.new)

    # Debug: print the actual HTML
    # puts rendered.to_html

    assert_selector ".theme-toggle-wrapper"

    # Check the wrapper div contains the expected content
    wrapper = rendered.at_css(".theme-toggle-wrapper")
    assert_not_nil wrapper, "Theme toggle wrapper should exist"

    # Check for data attributes in the HTML string
    html = rendered.to_html
    assert_match(/data-controller="theme"/, html)
    assert_match(/data-theme-storage-key-value="creative-theme"/, html)

    # Check button exists with correct action
    assert_selector "button[data-action='click->theme#toggle']"

    # Should have medium size classes
    assert_selector ".w-10"
    assert_selector ".h-10"
    assert_selector ".p-2"
  end

  test "renders with small size" do
    rendered = render_inline(ThemeToggleComponent.new(size: :sm))

    assert_selector ".w-8"
    assert_selector ".h-8"
    assert_selector ".p-1\\.5"
  end

  test "renders with large size" do
    rendered = render_inline(ThemeToggleComponent.new(size: :lg))

    assert_selector ".w-12"
    assert_selector ".h-12"
    assert_selector ".p-2\\.5"
  end

  test "renders with primary variant" do
    rendered = render_inline(ThemeToggleComponent.new(variant: :primary))

    assert_selector ".bg-creative-primary-100"
    assert_selector ".text-creative-primary-600"
  end

  test "renders with outline variant" do
    rendered = render_inline(ThemeToggleComponent.new(variant: :outline))

    assert_selector ".border-creative-neutral-300"
    assert_selector ".text-creative-neutral-600"
  end

  test "renders with ghost variant" do
    rendered = render_inline(ThemeToggleComponent.new(variant: :ghost))

    assert_selector ".text-creative-neutral-600"
  end

  test "renders with fixed top right position" do
    rendered = render_inline(ThemeToggleComponent.new(position: :fixed_top_right))

    assert_selector ".fixed"
    assert_selector ".top-4"
    assert_selector ".right-4"
    assert_selector ".z-50"
  end

  test "renders with fixed bottom right position" do
    rendered = render_inline(ThemeToggleComponent.new(position: :fixed_bottom_right))

    assert_selector ".fixed"
    assert_selector ".bottom-4"
    assert_selector ".right-4"
    assert_selector ".z-50"
  end

  test "renders with inline position" do
    rendered = render_inline(ThemeToggleComponent.new(position: :inline))

    assert_selector ".inline-flex"
  end

  test "accepts custom classes" do
    rendered = render_inline(ThemeToggleComponent.new(classes: "custom-class another-class"))

    assert_selector ".custom-class"
    assert_selector ".another-class"
  end

  test "combines all parameters correctly" do
    rendered = render_inline(ThemeToggleComponent.new(
      variant: :primary,
      size: :lg,
      position: :fixed_top_right,
      classes: "custom-toggle"
    ))

    # Position
    assert_selector ".fixed.top-4.right-4"
    # Size
    assert_selector ".w-12.h-12"
    # Variant
    assert_selector ".bg-creative-primary-100"
    # Custom
    assert_selector ".custom-toggle"
  end
end

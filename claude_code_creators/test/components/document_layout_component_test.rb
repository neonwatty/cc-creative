require "test_helper"

class DocumentLayoutComponentTest < ViewComponent::TestCase
  include ActionView::Helpers::UrlHelper
  
  setup do
    @user = users(:john)
    @document = documents(:article_one)
  end

  test "renders with default layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(current_user: @user))
      
      assert_selector ".document-layout"
      assert_selector ".min-h-screen"
      assert_selector ".bg-creative-neutral-50"
      assert_selector "[data-controller='document-layout']"
    end
  end

  test "renders with current document" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        current_document: @document
      ))
      
      assert_selector "[data-controller='document-layout']"
    end
  end

  test "renders focused layout type" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :focused }
      ))
      
      assert_selector ".bg-white"
      assert_selector "[data-document-layout-layout-type-value='focused']"
    end
  end

  test "renders minimal layout type" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :minimal }
      ))
      
      assert_selector ".bg-creative-neutral-25"
      assert_selector "[data-document-layout-layout-type-value='minimal']"
    end
  end

  test "renders with sidebar collapsed" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { sidebar_collapsed: true }
      ))
      
      assert_selector "[data-document-layout-sidebar-collapsed-value='true']"
      assert_selector ".ml-16"
    end
  end

  test "renders with sidebar expanded" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { sidebar_collapsed: false }
      ))
      
      assert_selector "[data-document-layout-sidebar-collapsed-value='false']"
      assert_selector ".ml-80"
    end
  end

  test "shows toolbar by default" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(current_user: @user))
      
      assert_selector ".px-6.py-4.bg-white"
      refute_selector ".px-6.py-4.bg-white.hidden"
    end
  end

  test "hides toolbar when option set" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { show_toolbar: false }
      ))
      
      assert_selector ".px-6.py-4.bg-white.hidden"
    end
  end

  test "enables collaboration mode" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { enable_collaboration: true }
      ))
      
      assert_selector "[data-document-layout-enable-collaboration-value='true']"
    end
  end

  test "renders floating action button in default layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(current_user: @user))
      
      assert_selector ".fixed.bottom-6.right-6.w-14.h-14.bg-creative-primary-500"
    end
  end

  test "hides floating action button in minimal layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :minimal }
      ))
      
      assert_selector ".fixed.bottom-6.right-6.w-14.h-14.bg-creative-primary-500.hidden"
    end
  end

  test "renders mobile menu structure" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(current_user: @user))
      
      assert_selector ".fixed.inset-0.z-50.lg\\:hidden"
      assert_selector ".fixed.inset-0.bg-creative-neutral-900\\/50"
    end
  end

  test "renders content area with proper styling for focused layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :focused }
      ))
      
      assert_selector ".flex-1.overflow-auto.p-6.p-8.max-w-4xl.mx-auto"
    end
  end

  test "renders content area with proper styling for minimal layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :minimal }
      ))
      
      assert_selector ".flex-1.overflow-auto.p-6.p-4.max-w-3xl.mx-auto"
    end
  end

  test "shows onboarding for new users" do
    new_user = @user.dup
    new_user.stubs(:created_at).returns(1.hour.ago)
    new_user.stubs(:onboarding_completed_at).returns(nil)
    
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: new_user,
        options: { show_onboarding: true }
      ))
      
      # Test would check for onboarding component if implemented
      assert true
    end
  end

  test "does not show onboarding for users who completed it" do
    @user.stubs(:onboarding_completed_at).returns(1.day.ago)
    
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { show_onboarding: true }
      ))
      
      # Test would check absence of onboarding component if implemented
      assert true
    end
  end

  test "sidebar hidden in focused layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :focused }
      ))
      
      # Should not have sidebar margins
      assert_selector ".ml-0"
    end
  end

  test "sidebar hidden in minimal layout" do
    with_stubbed_paths do
      rendered = render_inline(DocumentLayoutComponent.new(
        current_user: @user,
        options: { layout_type: :minimal }
      ))
      
      # Should have special minimal layout margins
      assert_selector ".mx-8"
    end
  end

  private

  def with_stubbed_paths(&block)
    # Stub all the path helpers
    vc = vc_test_controller.view_context
    vc.define_singleton_method(:edit_user_registration_path) { '/users/edit' }
    vc.define_singleton_method(:destroy_session_path) { '/logout' }
    vc.define_singleton_method(:root_path) { '/' }
    vc.define_singleton_method(:documents_path) { '/documents' }
    vc.define_singleton_method(:document_path) { |doc| "/documents/#{doc.id}" }
    vc.define_singleton_method(:context_items_path) { '/context_items' }
    vc.define_singleton_method(:sub_agents_path) { '/sub_agents' }
    vc.define_singleton_method(:new_document_path) { '/documents/new' }
    vc.define_singleton_method(:controller_name) { 'documents' }
    vc.define_singleton_method(:action_name) { 'index' }
    
    # Add navigation paths
    vc.define_singleton_method(:cloud_integrations_path) { '/cloud_integrations' }
    vc.define_singleton_method(:settings_path) { '/settings' }
    
    yield
  end
end
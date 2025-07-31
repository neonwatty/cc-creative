require "test_helper"

class OnboardingModalComponentTest < ViewComponent::TestCase
  include ActionView::Helpers::UrlHelper
  
  setup do
    @user = users(:john)
  end

  test "renders with default settings" do
    rendered = render_inline(OnboardingModalComponent.new(current_user: @user))
    
    assert_selector ".fixed.inset-0.z-50"
    assert_selector ".bg-creative-neutral-900\\/75"
    assert_selector ".max-w-2xl"
  end

  test "shows onboarding for new users" do
    new_user = @user.dup
    new_user.stubs(:created_at).returns(1.hour.ago)
    new_user.stubs(:onboarding_completed_at).returns(nil)
    
    rendered = render_inline(OnboardingModalComponent.new(current_user: new_user))
    
    assert_selector ".opacity-100.visible"
    refute_selector ".opacity-0.invisible"
  end

  test "hides onboarding for users who completed it" do
    @user.stubs(:onboarding_completed_at).returns(1.day.ago)
    @user.stubs(:created_at).returns(2.days.ago)
    
    rendered = render_inline(OnboardingModalComponent.new(current_user: @user))
    
    assert_selector ".opacity-0.invisible"
    refute_selector ".opacity-100.visible"
  end

  test "shows onboarding when force_show is true" do
    @user.stubs(:onboarding_completed_at).returns(1.day.ago)
    
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { force_show: true }
    ))
    
    assert_selector ".opacity-100.visible"
  end

  test "renders step 1 content" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 1, force_show: true }
    ))
    
    assert_text "Welcome to Claude Code Creators!"
    assert_text "Your AI-powered creative writing platform"
    assert_text "AI-Powered Writing"
    assert_text "Sub-Agents"
    assert_text "Context Management"
  end

  test "renders step 2 content" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 2, force_show: true }
    ))
    
    assert_text "Document Editor"
    assert_text "Rich text editing with AI assistance"
    assert_text "Rich Text Editor"
    assert_text "Auto-save"
    assert_text "Live Preview"
  end

  test "renders step 3 content" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 3, force_show: true }
    ))
    
    assert_text "Context & Sub-Agents"
    assert_text "Organize your creative process"
    assert_text "Context Items"
    assert_text "Sub-Agents"
    assert_text "Drag & Drop"
  end

  test "renders step 4 content" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 4, force_show: true }
    ))
    
    assert_text "You're All Set!"
    assert_text "Start creating amazing content"
    assert_text "Create Your First Document"
    assert_text "Explore Examples"
    assert_text "Get Help"
  end

  test "renders progress indicators" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 2, force_show: true }
    ))
    
    # Step 1 should be completed
    assert_selector ".bg-creative-secondary-500", count: 1
    
    # Step 2 should be current
    assert_selector ".bg-creative-primary-500.ring-4", count: 1
    
    # Steps 3 and 4 should be pending
    assert_selector ".bg-creative-neutral-200", count: 2
  end

  test "shows previous button on step 2" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 2, force_show: true }
    ))
    
    assert_selector "button", text: "Previous"
  end

  test "hides previous button on step 1" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 1, force_show: true }
    ))
    
    refute_selector "button", text: "Previous"
  end

  test "shows next button on non-final steps" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 1, force_show: true }
    ))
    
    assert_selector "button", text: "Next"
  end

  test "shows finish button on final step" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 4, force_show: true }
    ))
    
    assert_selector "button", text: "Get Started"
    refute_selector "button", text: "Next"
  end

  test "renders close button" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { force_show: true }
    ))
    
    assert_selector ".absolute.top-4.right-4"
  end

  test "renders feature cards" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { force_show: true }
    ))
    
    assert_selector ".bg-creative-neutral-50"
  end

  test "renders action cards on final step" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 4, force_show: true }
    ))
    
    assert_selector ".from-creative-primary-50.to-creative-secondary-50"
  end

  test "applies hover effects" do
    rendered = render_inline(OnboardingModalComponent.new(
      current_user: @user,
      options: { current_step: 4, force_show: true }
    ))
    
    assert_selector ".hover\\:scale-105"
  end
end
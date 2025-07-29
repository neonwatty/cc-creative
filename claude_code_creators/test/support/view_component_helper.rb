# ViewComponent test configuration
class ViewComponent::TestCase
  # Include Rails URL helpers for components that need them
  include Rails.application.routes.url_helpers
  
  # Set default URL options
  def default_url_options
    { host: 'localhost:3000' }
  end
end

# Ensure ViewComponent::Base includes URL helpers
ViewComponent::Base.class_eval do
  include Rails.application.routes.url_helpers
  
  def default_url_options
    { host: 'localhost:3000' }
  end
end
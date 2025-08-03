require_relative "config/environment"

user = User.create!(
  name: "Test User",
  email_address: "test@example.com",
  password: "password",
  password_confirmation: "password",
  email_confirmed: true,
  email_confirmed_at: Time.current
)

document = Document.create!(
  title: "Test Document",
  description: "A test document for system tests",
  content: "This is test content",
  user: user
)

puts "Created user: #{user.email_address}"
puts "Created document: #{document.title} (ID: #{document.id})"
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "./channels/sub_agent_channel"
import "./channels/cloud_sync_channel"

import "trix"
import "@rails/actiontext"

// Import Prism.js for syntax highlighting
import Prism from "prismjs"
import "prismjs/themes/prism.css"
// Import common language support
import "prismjs/components/prism-javascript"
import "prismjs/components/prism-typescript"
import "prismjs/components/prism-ruby"
import "prismjs/components/prism-python"
import "prismjs/components/prism-java"
import "prismjs/components/prism-css"
import "prismjs/components/prism-scss"
import "prismjs/components/prism-html"
import "prismjs/components/prism-json"
import "prismjs/components/prism-sql"
import "prismjs/components/prism-bash"
import "prismjs/components/prism-yaml"
import "prismjs/components/prism-markdown"

// Make Prism globally available
window.Prism = Prism

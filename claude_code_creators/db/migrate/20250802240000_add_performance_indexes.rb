class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Document performance indexes
    add_index :documents, [:user_id, :updated_at], name: 'idx_documents_user_updated'
    add_index :documents, [:created_at, :user_id], name: 'idx_documents_created_user'
    add_index :documents, :current_version_number, name: 'idx_documents_version'
    
    # Context items performance indexes
    add_index :context_items, [:document_id, :created_at], name: 'idx_context_items_doc_created'
    add_index :context_items, [:user_id, :created_at], name: 'idx_context_items_user_created'
    add_index :context_items, [:item_type, :created_at], name: 'idx_context_items_type_created'
    add_index :context_items, [:document_id, :position, :created_at], name: 'idx_context_items_doc_pos_created'
    
    # Claude context performance indexes
    add_index :claude_contexts, [:document_id, :context_type, :created_at], name: 'idx_claude_contexts_doc_type_created'
    add_index :claude_contexts, [:session_id, :created_at], name: 'idx_claude_contexts_session_created'
    
    # Sub agent performance indexes
    add_index :sub_agents, [:document_id, :status, :created_at], name: 'idx_sub_agents_doc_status_created'
    add_index :sub_agents, [:user_id, :status], name: 'idx_sub_agents_user_status'
    add_index :sub_agents, [:agent_type, :status], name: 'idx_sub_agents_type_status'
    
    # Command history performance indexes
    add_index :command_histories, [:user_id, :status, :executed_at], name: 'idx_command_histories_user_status_executed'
    add_index :command_histories, [:document_id, :status, :executed_at], name: 'idx_command_histories_doc_status_executed'
    add_index :command_histories, [:command, :executed_at], name: 'idx_command_histories_command_executed'
    
    # Operational transforms performance indexes
    add_index :operational_transforms, [:document_id, :user_id, :timestamp], name: 'idx_operational_transforms_doc_user_time'
    add_index :operational_transforms, [:status, :timestamp], name: 'idx_operational_transforms_status_time'
    add_index :operational_transforms, [:operation_type, :timestamp], name: 'idx_operational_transforms_type_time'
    
    # Performance logs optimization indexes
    add_index :performance_logs, [:operation, :environment, :occurred_at], name: 'idx_performance_logs_op_env_occurred'
    add_index :performance_logs, [:duration_ms, :operation], name: 'idx_performance_logs_duration_op'
    add_index :performance_logs, [:environment, :duration_ms], name: 'idx_performance_logs_env_duration'
    
    # Error logs optimization indexes  
    add_index :error_logs, [:error_class, :environment, :occurred_at], name: 'idx_error_logs_class_env_occurred'
    add_index :error_logs, [:environment, :occurred_at], name: 'idx_error_logs_env_occurred'
    
    # Business event logs optimization indexes
    add_index :business_event_logs, [:event_name, :environment, :occurred_at], name: 'idx_business_event_logs_name_env_occurred'
    
    # Collaboration sessions performance indexes
    add_index :collaboration_sessions, [:document_id, :status, :started_at], name: 'idx_collaboration_sessions_doc_status_started'
    add_index :collaboration_sessions, [:user_id, :status], name: 'idx_collaboration_sessions_user_status'
    add_index :collaboration_sessions, [:expires_at, :status], name: 'idx_collaboration_sessions_expires_status'
    
    # Document versions performance indexes
    add_index :document_versions, [:document_id, :is_auto_version, :created_at], name: 'idx_document_versions_doc_auto_created'
    add_index :document_versions, [:created_by_user_id, :created_at], name: 'idx_document_versions_user_created'
    
    # Plugin related performance indexes
    add_index :plugin_installations, [:user_id, :status, :last_used_at], name: 'idx_plugin_installations_user_status_used'
    add_index :plugin_installations, [:plugin_id, :status], name: 'idx_plugin_installations_plugin_status'
    add_index :extension_logs, [:plugin_id, :status, :created_at], name: 'idx_extension_logs_plugin_status_created'
    add_index :extension_logs, [:user_id, :action, :created_at], name: 'idx_extension_logs_user_action_created'
    
    # Cloud integration performance indexes
    add_index :cloud_files, [:cloud_integration_id, :last_synced_at], name: 'idx_cloud_files_integration_synced'
    add_index :cloud_files, [:document_id, :provider], name: 'idx_cloud_files_doc_provider'
    add_index :cloud_integrations, [:user_id, :provider], name: 'idx_cloud_integrations_user_provider'
    
    # User related performance indexes
    add_index :sessions, [:user_id, :created_at], name: 'idx_sessions_user_created'
    add_index :users, [:role, :created_at], name: 'idx_users_role_created'
    add_index :users, [:email_confirmed, :created_at], name: 'idx_users_confirmed_created'
  end
  
  def down
    # Remove indexes in reverse order
    remove_index :users, name: 'idx_users_confirmed_created'
    remove_index :users, name: 'idx_users_role_created'
    remove_index :sessions, name: 'idx_sessions_user_created'
    
    remove_index :cloud_integrations, name: 'idx_cloud_integrations_user_provider'
    remove_index :cloud_files, name: 'idx_cloud_files_doc_provider'
    remove_index :cloud_files, name: 'idx_cloud_files_integration_synced'
    
    remove_index :extension_logs, name: 'idx_extension_logs_user_action_created'
    remove_index :extension_logs, name: 'idx_extension_logs_plugin_status_created'
    remove_index :plugin_installations, name: 'idx_plugin_installations_plugin_status'
    remove_index :plugin_installations, name: 'idx_plugin_installations_user_status_used'
    
    remove_index :document_versions, name: 'idx_document_versions_user_created'
    remove_index :document_versions, name: 'idx_document_versions_doc_auto_created'
    
    remove_index :collaboration_sessions, name: 'idx_collaboration_sessions_expires_status'
    remove_index :collaboration_sessions, name: 'idx_collaboration_sessions_user_status'
    remove_index :collaboration_sessions, name: 'idx_collaboration_sessions_doc_status_started'
    
    remove_index :business_event_logs, name: 'idx_business_event_logs_name_env_occurred'
    remove_index :error_logs, name: 'idx_error_logs_env_occurred'
    remove_index :error_logs, name: 'idx_error_logs_class_env_occurred'
    
    remove_index :performance_logs, name: 'idx_performance_logs_env_duration'
    remove_index :performance_logs, name: 'idx_performance_logs_duration_op'
    remove_index :performance_logs, name: 'idx_performance_logs_op_env_occurred'
    
    remove_index :operational_transforms, name: 'idx_operational_transforms_type_time'
    remove_index :operational_transforms, name: 'idx_operational_transforms_status_time'
    remove_index :operational_transforms, name: 'idx_operational_transforms_doc_user_time'
    
    remove_index :command_histories, name: 'idx_command_histories_command_executed'
    remove_index :command_histories, name: 'idx_command_histories_doc_status_executed'
    remove_index :command_histories, name: 'idx_command_histories_user_status_executed'
    
    remove_index :sub_agents, name: 'idx_sub_agents_type_status'
    remove_index :sub_agents, name: 'idx_sub_agents_user_status'
    remove_index :sub_agents, name: 'idx_sub_agents_doc_status_created'
    
    remove_index :claude_contexts, name: 'idx_claude_contexts_session_created'
    remove_index :claude_contexts, name: 'idx_claude_contexts_doc_type_created'
    
    remove_index :context_items, name: 'idx_context_items_doc_pos_created'
    remove_index :context_items, name: 'idx_context_items_type_created'
    remove_index :context_items, name: 'idx_context_items_user_created'
    remove_index :context_items, name: 'idx_context_items_doc_created'
    
    remove_index :documents, name: 'idx_documents_version'
    remove_index :documents, name: 'idx_documents_created_user'
    remove_index :documents, name: 'idx_documents_user_updated'
  end
end
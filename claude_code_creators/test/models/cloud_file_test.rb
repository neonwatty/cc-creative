require "test_helper"

class CloudFileTest < ActiveSupport::TestCase
  setup do
    @cloud_integration = cloud_integrations(:one)
    @cloud_file = cloud_files(:one)
    @document = documents(:one)
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    cloud_file = CloudFile.new(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'test_file_id',
      name: 'test.txt',
      mime_type: 'text/plain'
    )
    assert cloud_file.valid?
  end

  test "should require a cloud integration" do
    @cloud_file.cloud_integration = nil
    assert_not @cloud_file.valid?
    assert_includes @cloud_file.errors[:cloud_integration], "must exist"
  end

  test "should require a provider" do
    @cloud_file.provider = nil
    assert_not @cloud_file.valid?
    assert_includes @cloud_file.errors[:provider], "can't be blank"
  end

  test "should require a file_id" do
    @cloud_file.file_id = nil
    assert_not @cloud_file.valid?
    assert_includes @cloud_file.errors[:file_id], "can't be blank"
  end

  test "should require a name" do
    @cloud_file.name = nil
    assert_not @cloud_file.valid?
    assert_includes @cloud_file.errors[:name], "can't be blank"
  end

  test "should enforce uniqueness of file_id per cloud_integration" do
    duplicate = CloudFile.new(
      cloud_integration: @cloud_file.cloud_integration,
      provider: 'google_drive',
      file_id: @cloud_file.file_id,
      name: 'different_name.txt',
      mime_type: 'text/plain'
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:file_id], "has already been taken"
  end

  test "should allow same file_id for different cloud_integrations" do
    different_integration = cloud_integrations(:two)
    cloud_file = CloudFile.new(
      cloud_integration: different_integration,
      provider: 'google_drive',
      file_id: @cloud_file.file_id,
      name: 'test.txt',
      mime_type: 'text/plain'
    )
    assert cloud_file.valid?
  end

  # Association Tests
  test "should belong to cloud integration" do
    assert_respond_to @cloud_file, :cloud_integration
    assert_instance_of CloudIntegration, @cloud_file.cloud_integration
  end

  test "should have user through cloud integration" do
    assert_respond_to @cloud_file, :user
    assert_equal @cloud_file.cloud_integration.user, @cloud_file.user
  end

  test "should optionally belong to document" do
    assert_respond_to @cloud_file, :document
    
    # Test without document
    @cloud_file.document = nil
    assert @cloud_file.valid?
    
    # Test with document
    @cloud_file.document = @document
    assert @cloud_file.valid?
    assert_equal @document, @cloud_file.document
  end

  # Scope Tests
  test "recent scope should order by created_at desc" do
    # Delete existing fixtures to ensure clean test
    CloudFile.destroy_all
    
    old_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'old_file',
      name: 'old.txt',
      mime_type: 'text/plain',
      created_at: 2.hours.ago
    )
    
    new_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'new_file',
      name: 'new.txt',
      mime_type: 'text/plain',
      created_at: 1.hour.ago
    )

    recent_files = CloudFile.recent
    assert_equal new_file, recent_files.first
    assert_equal old_file, recent_files.second
  end

  test "synced scope should return only synced files" do
    synced_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'synced_file',
      name: 'synced.txt',
      mime_type: 'text/plain',
      last_synced_at: 1.hour.ago
    )
    
    unsynced_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'unsynced_file',
      name: 'unsynced.txt',
      mime_type: 'text/plain',
      last_synced_at: nil
    )

    synced_files = CloudFile.synced
    assert_includes synced_files, synced_file
    assert_not_includes synced_files, unsynced_file
  end

  test "by_provider scope should filter by provider" do
    google_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'google_file',
      name: 'google.txt',
      mime_type: 'text/plain'
    )
    
    dropbox_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'dropbox',
      file_id: 'dropbox_file',
      name: 'dropbox.txt',
      mime_type: 'text/plain'
    )

    google_files = CloudFile.by_provider('google_drive')
    assert_includes google_files, google_file
    assert_not_includes google_files, dropbox_file
  end

  test "importable scope should return only importable files" do
    importable_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'importable_file',
      name: 'document.txt',
      mime_type: 'text/plain'
    )
    
    non_importable_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'non_importable_file',
      name: 'image.jpg',
      mime_type: 'image/jpeg'
    )

    importable_files = CloudFile.importable
    assert_includes importable_files, importable_file
    assert_not_includes importable_files, non_importable_file
  end

  # Instance Method Tests
  test "importable? should return true for supported mime types" do
    CloudFile::IMPORTABLE_MIME_TYPES.each do |mime_type|
      @cloud_file.mime_type = mime_type
      assert @cloud_file.importable?, "#{mime_type} should be importable"
    end
  end

  test "importable? should return false for unsupported mime types" do
    unsupported_types = ['image/jpeg', 'video/mp4', 'audio/mp3', 'application/zip']
    unsupported_types.each do |mime_type|
      @cloud_file.mime_type = mime_type
      assert_not @cloud_file.importable?, "#{mime_type} should not be importable"
    end
  end

  test "human_size should format file sizes correctly" do
    # Test bytes
    @cloud_file.size = 512
    assert_equal '512 B', @cloud_file.human_size

    # Test kilobytes
    @cloud_file.size = 1536  # 1.5 KB
    assert_equal '1.5 KB', @cloud_file.human_size

    # Test megabytes
    @cloud_file.size = 1_572_864  # 1.5 MB
    assert_equal '1.5 MB', @cloud_file.human_size

    # Test gigabytes  
    @cloud_file.size = 1_610_612_736  # 1.5 GB
    assert_equal '1.5 GB', @cloud_file.human_size

    # Test nil size
    @cloud_file.size = nil
    assert_equal 'Unknown', @cloud_file.human_size
  end

  test "file type helper methods should work correctly" do
    # Test Google Doc
    @cloud_file.mime_type = 'application/vnd.google-apps.document'
    assert @cloud_file.google_doc?
    assert_not @cloud_file.pdf?
    assert_not @cloud_file.text?
    assert_not @cloud_file.word_doc?

    # Test PDF
    @cloud_file.mime_type = 'application/pdf'
    assert_not @cloud_file.google_doc?
    assert @cloud_file.pdf?
    assert_not @cloud_file.text?
    assert_not @cloud_file.word_doc?

    # Test text files
    @cloud_file.mime_type = 'text/plain'
    assert_not @cloud_file.google_doc?
    assert_not @cloud_file.pdf?
    assert @cloud_file.text?
    assert_not @cloud_file.word_doc?

    # Test Word documents
    @cloud_file.mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    assert_not @cloud_file.google_doc?
    assert_not @cloud_file.pdf?
    assert_not @cloud_file.text?
    assert @cloud_file.word_doc?

    @cloud_file.mime_type = 'application/msword'
    assert @cloud_file.word_doc?
  end

  # Metadata Methods Tests
  test "get_metadata should return metadata value" do
    @cloud_file.metadata = { 'key' => 'value', 'nested' => { 'inner' => 'data' } }
    assert_equal 'value', @cloud_file.get_metadata('key')
    assert_equal({ 'inner' => 'data' }, @cloud_file.get_metadata('nested'))
  end

  test "get_metadata should return nil for non-existent key" do
    @cloud_file.metadata = { 'key' => 'value' }
    assert_nil @cloud_file.get_metadata('nonexistent')
  end

  test "set_metadata should set metadata value" do
    @cloud_file.set_metadata('new_key', 'new_value')
    assert_equal 'new_value', @cloud_file.metadata['new_key']
  end

  test "set_metadata should initialize metadata if nil" do
    @cloud_file.metadata = nil
    @cloud_file.set_metadata('key', 'value')
    assert_equal({ 'key' => 'value' }, @cloud_file.metadata)
  end

  # Sync Status Tests
  test "synced? should return true when last_synced_at is present" do
    @cloud_file.last_synced_at = 1.hour.ago
    assert @cloud_file.synced?
  end

  test "synced? should return false when last_synced_at is nil" do
    @cloud_file.last_synced_at = nil
    assert_not @cloud_file.synced?
  end

  test "sync_needed? should return true when never synced" do
    @cloud_file.last_synced_at = nil
    assert @cloud_file.sync_needed?
  end

  test "sync_needed? should return true when synced over an hour ago" do
    @cloud_file.last_synced_at = 2.hours.ago
    assert @cloud_file.sync_needed?
  end

  test "sync_needed? should return false when recently synced" do
    @cloud_file.last_synced_at = 30.minutes.ago
    assert_not @cloud_file.sync_needed?
  end

  # Provider URL Tests
  test "provider_url should return correct URLs for each provider" do
    file_id = 'test_file_123'
    
    # Google Drive
    @cloud_file.provider = 'google_drive'
    @cloud_file.file_id = file_id
    expected_url = "https://drive.google.com/file/d/#{file_id}/view"
    assert_equal expected_url, @cloud_file.provider_url

    # Dropbox
    @cloud_file.provider = 'dropbox'
    @cloud_file.file_id = file_id
    expected_url = "https://www.dropbox.com/home?preview=#{file_id}"
    assert_equal expected_url, @cloud_file.provider_url

    # Notion (uses metadata URL)
    @cloud_file.provider = 'notion'
    @cloud_file.file_id = file_id
    @cloud_file.metadata = { 'url' => 'https://notion.so/page/123' }
    assert_equal 'https://notion.so/page/123', @cloud_file.provider_url
  end

  test "provider_url should return nil for notion without metadata url" do
    @cloud_file.provider = 'notion'
    @cloud_file.file_id = 'test_file'
    @cloud_file.metadata = {}
    assert_nil @cloud_file.provider_url
  end

  # JSON Serialization Tests
  test "should serialize metadata as JSON" do
    metadata_hash = { 
      'author' => 'John Doe', 
      'tags' => ['important', 'draft'],
      'permissions' => { 'read' => true, 'write' => false }
    }
    @cloud_file.metadata = metadata_hash
    @cloud_file.save!
    
    @cloud_file.reload
    assert_equal metadata_hash, @cloud_file.metadata
  end

  # Edge Cases and Error Handling
  test "should handle nil mime_type gracefully in text? method" do
    @cloud_file.mime_type = nil
    assert_not @cloud_file.text?
  end

  test "should handle empty file_id in provider_url" do
    @cloud_file.file_id = ''
    @cloud_file.provider = 'google_drive'
    
    # Should still generate URL even with empty file_id
    expected_url = "https://drive.google.com/file/d//view"
    assert_equal expected_url, @cloud_file.provider_url
  end

  test "should handle very large file sizes" do
    @cloud_file.size = 5_368_709_120  # 5 GB
    assert_equal '5.0 GB', @cloud_file.human_size
  end

  # Constants Tests
  test "IMPORTABLE_MIME_TYPES should include all expected types" do
    expected_types = [
      'text/plain',
      'text/html',
      'text/markdown',
      'application/pdf',
      'application/vnd.google-apps.document',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/msword'
    ]
    
    expected_types.each do |mime_type|
      assert_includes CloudFile::IMPORTABLE_MIME_TYPES, mime_type
    end
  end
end

class BackupService
  BACKUP_TYPES = %w[database files logs].freeze
  BACKUP_RETENTION = {
    daily: 30.days,
    weekly: 12.weeks,
    monthly: 12.months
  }.freeze

  class << self
    def create_full_backup(backup_type = "manual")
      backup_id = SecureRandom.uuid
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")

      Rails.logger.info("Starting full backup: #{backup_id}")

      backup_manifest = {
        backup_id: backup_id,
        backup_type: backup_type,
        started_at: Time.current.iso8601,
        components: {}
      }

      begin
        # Create database backup
        database_backup = create_database_backup(backup_id, timestamp)
        backup_manifest[:components][:database] = database_backup

        # Create files backup
        files_backup = create_files_backup(backup_id, timestamp)
        backup_manifest[:components][:files] = files_backup

        # Create logs backup
        logs_backup = create_logs_backup(backup_id, timestamp)
        backup_manifest[:components][:logs] = logs_backup

        backup_manifest[:completed_at] = Time.current.iso8601
        backup_manifest[:status] = "completed"
        backup_manifest[:total_size_mb] = calculate_backup_size(backup_manifest)

        # Save backup manifest
        save_backup_manifest(backup_id, backup_manifest)

        # Cleanup old backups
        cleanup_old_backups(backup_type)

        Rails.logger.info("Full backup completed: #{backup_id}")
        backup_manifest

      rescue => e
        backup_manifest[:completed_at] = Time.current.iso8601
        backup_manifest[:status] = "failed"
        backup_manifest[:error] = e.message

        save_backup_manifest(backup_id, backup_manifest)
        ErrorTrackingService.track_error(e, { backup_id: backup_id })

        Rails.logger.error("Backup failed: #{backup_id} - #{e.message}")
        raise
      end
    end

    def restore_from_backup(backup_id, components = %w[database files])
      manifest = load_backup_manifest(backup_id)
      return false unless manifest

      Rails.logger.info("Starting restore from backup: #{backup_id}")

      begin
        if components.include?("database") && manifest[:components][:database]
          restore_database_backup(manifest[:components][:database])
        end

        if components.include?("files") && manifest[:components][:files]
          restore_files_backup(manifest[:components][:files])
        end

        Rails.logger.info("Restore completed: #{backup_id}")
        true

      rescue => e
        ErrorTrackingService.track_error(e, { backup_id: backup_id, restore_components: components })
        Rails.logger.error("Restore failed: #{backup_id} - #{e.message}")
        raise
      end
    end

    def list_backups(backup_type = nil)
      backup_dir = ENV["BACKUP_DIRECTORY"] || Rails.root.join("backups")
      pattern = backup_type ? "#{backup_type}_*_manifest.json" : "*_manifest.json"

      Dir.glob(File.join(backup_dir, pattern))
         .map { |file| JSON.parse(File.read(file), symbolize_names: true) }
         .sort_by { |manifest| manifest[:started_at] }
         .reverse
    end

    def verify_backup(backup_id)
      manifest = load_backup_manifest(backup_id)
      return { valid: false, error: "Manifest not found" } unless manifest

      verification_results = {
        backup_id: backup_id,
        verified_at: Time.current.iso8601,
        components: {}
      }

      # Verify database backup
      if manifest[:components][:database]
        verification_results[:components][:database] = verify_database_backup(
          manifest[:components][:database]
        )
      end

      # Verify files backup
      if manifest[:components][:files]
        verification_results[:components][:files] = verify_files_backup(
          manifest[:components][:files]
        )
      end

      # Check overall validity
      all_valid = verification_results[:components].values.all? { |result| result[:valid] }
      verification_results[:valid] = all_valid

      verification_results
    end

    private

    def create_database_backup(backup_id, timestamp)
      backup_dir = ensure_backup_directory("database")
      filename = "#{backup_id}_#{timestamp}_database.sql"
      filepath = File.join(backup_dir, filename)

      database_config = ActiveRecord::Base.connection_config

      case database_config[:adapter]
      when "postgresql"
        create_postgresql_backup(filepath, database_config)
      when "mysql2"
        create_mysql_backup(filepath, database_config)
      else
        raise "Unsupported database adapter: #{database_config[:adapter]}"
      end

      {
        type: "database",
        filename: filename,
        filepath: filepath,
        size_mb: (File.size(filepath) / 1024.0 / 1024.0).round(2),
        created_at: Time.current.iso8601,
        checksum: calculate_file_checksum(filepath)
      }
    end

    def create_postgresql_backup(filepath, config)
      host = config[:host] || "localhost"
      port = config[:port] || 5432
      database = config[:database]
      username = config[:username]

      env_vars = {}
      env_vars["PGPASSWORD"] = config[:password] if config[:password]

      command = [
        "pg_dump",
        "--host", host.to_s,
        "--port", port.to_s,
        "--username", username.to_s,
        "--no-password",
        "--format", "custom",
        "--compress", "9",
        "--file", filepath,
        database
      ]

      success = system(env_vars, *command)
      raise "PostgreSQL backup failed" unless success
    end

    def create_mysql_backup(filepath, config)
      host = config[:host] || "localhost"
      port = config[:port] || 3306
      database = config[:database]
      username = config[:username]
      password = config[:password]

      command = [
        "mysqldump",
        "--host", host.to_s,
        "--port", port.to_s,
        "--user", username.to_s
      ]

      command += [ "--password", password ] if password
      command += [
        "--single-transaction",
        "--routines",
        "--triggers",
        "--result-file", filepath,
        database
      ]

      success = system(*command)
      raise "MySQL backup failed" unless success
    end

    def create_files_backup(backup_id, timestamp)
      backup_dir = ensure_backup_directory("files")
      filename = "#{backup_id}_#{timestamp}_files.tar.gz"
      filepath = File.join(backup_dir, filename)

      # Directories to backup
      source_dirs = [
        Rails.root.join("storage"),
        Rails.root.join("log"),
        Rails.root.join("public", "uploads")
      ].select(&:exist?)

      return nil if source_dirs.empty?

      command = [ "tar", "-czf", filepath ] + source_dirs.map(&:to_s)
      success = system(*command)
      raise "Files backup failed" unless success

      {
        type: "files",
        filename: filename,
        filepath: filepath,
        size_mb: (File.size(filepath) / 1024.0 / 1024.0).round(2),
        created_at: Time.current.iso8601,
        checksum: calculate_file_checksum(filepath),
        source_directories: source_dirs.map(&:to_s)
      }
    end

    def create_logs_backup(backup_id, timestamp)
      backup_dir = ensure_backup_directory("logs")
      filename = "#{backup_id}_#{timestamp}_logs.tar.gz"
      filepath = File.join(backup_dir, filename)

      log_dirs = [
        Rails.root.join("log")
      ].select(&:exist?)

      return nil if log_dirs.empty?

      command = [ "tar", "-czf", filepath ] + log_dirs.map(&:to_s)
      success = system(*command)
      raise "Logs backup failed" unless success

      {
        type: "logs",
        filename: filename,
        filepath: filepath,
        size_mb: (File.size(filepath) / 1024.0 / 1024.0).round(2),
        created_at: Time.current.iso8601,
        checksum: calculate_file_checksum(filepath)
      }
    end

    def restore_database_backup(backup_info)
      database_config = ActiveRecord::Base.connection_config

      case database_config[:adapter]
      when "postgresql"
        restore_postgresql_backup(backup_info[:filepath], database_config)
      when "mysql2"
        restore_mysql_backup(backup_info[:filepath], database_config)
      else
        raise "Unsupported database adapter: #{database_config[:adapter]}"
      end
    end

    def restore_postgresql_backup(filepath, config)
      host = config[:host] || "localhost"
      port = config[:port] || 5432
      database = config[:database]
      username = config[:username]

      env_vars = {}
      env_vars["PGPASSWORD"] = config[:password] if config[:password]

      # Drop and recreate database (be careful!)
      command = [
        "pg_restore",
        "--host", host.to_s,
        "--port", port.to_s,
        "--username", username.to_s,
        "--no-password",
        "--clean",
        "--create",
        "--dbname", database,
        filepath
      ]

      success = system(env_vars, *command)
      raise "PostgreSQL restore failed" unless success
    end

    def restore_mysql_backup(filepath, config)
      host = config[:host] || "localhost"
      port = config[:port] || 3306
      database = config[:database]
      username = config[:username]
      password = config[:password]

      command = [
        "mysql",
        "--host", host.to_s,
        "--port", port.to_s,
        "--user", username.to_s
      ]

      command += [ "--password", password ] if password
      command += [ database ]

      success = system("#{command.join(' ')} < #{filepath}")
      raise "MySQL restore failed" unless success
    end

    def restore_files_backup(backup_info)
      # Extract files to temporary directory first
      temp_dir = Dir.mktmpdir("restore_files")

      begin
        command = [ "tar", "-xzf", backup_info[:filepath], "-C", temp_dir ]
        success = system(*command)
        raise "Files extraction failed" unless success

        # Move files to correct locations
        backup_info[:source_directories]&.each do |source_dir|
          restored_dir = File.join(temp_dir, source_dir)
          if File.exist?(restored_dir)
            FileUtils.cp_r(restored_dir, File.dirname(source_dir), remove_destination: true)
          end
        end

      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    def verify_database_backup(backup_info)
      return { valid: false, error: "File not found" } unless File.exist?(backup_info[:filepath])

      # Verify file integrity
      current_checksum = calculate_file_checksum(backup_info[:filepath])
      checksum_valid = current_checksum == backup_info[:checksum]

      {
        valid: checksum_valid,
        checksum_match: checksum_valid,
        current_checksum: current_checksum,
        expected_checksum: backup_info[:checksum]
      }
    end

    def verify_files_backup(backup_info)
      return { valid: false, error: "File not found" } unless File.exist?(backup_info[:filepath])

      # Verify file integrity
      current_checksum = calculate_file_checksum(backup_info[:filepath])
      checksum_valid = current_checksum == backup_info[:checksum]

      {
        valid: checksum_valid,
        checksum_match: checksum_valid,
        current_checksum: current_checksum,
        expected_checksum: backup_info[:checksum]
      }
    end

    def cleanup_old_backups(backup_type)
      case backup_type
      when "daily"
        retention_period = BACKUP_RETENTION[:daily]
      when "weekly"
        retention_period = BACKUP_RETENTION[:weekly]
      when "monthly"
        retention_period = BACKUP_RETENTION[:monthly]
      else
        retention_period = 7.days # Default retention for manual backups
      end

      cutoff_date = retention_period.ago

      old_backups = list_backups(backup_type).select do |backup|
        Date.parse(backup[:started_at]) < cutoff_date.to_date
      end

      old_backups.each do |backup|
        delete_backup(backup[:backup_id])
      end
    end

    def delete_backup(backup_id)
      manifest = load_backup_manifest(backup_id)
      return unless manifest

      # Delete backup files
      manifest[:components]&.each do |_type, component|
        File.delete(component[:filepath]) if component[:filepath] && File.exist?(component[:filepath])
      end

      # Delete manifest
      manifest_path = backup_manifest_path(backup_id)
      File.delete(manifest_path) if File.exist?(manifest_path)

      Rails.logger.info("Deleted backup: #{backup_id}")
    end

    def ensure_backup_directory(type = nil)
      base_dir = ENV["BACKUP_DIRECTORY"] || Rails.root.join("backups")
      dir = type ? File.join(base_dir, type) : base_dir
      FileUtils.mkdir_p(dir)
      dir
    end

    def save_backup_manifest(backup_id, manifest)
      manifest_path = backup_manifest_path(backup_id)
      File.write(manifest_path, JSON.pretty_generate(manifest))
    end

    def load_backup_manifest(backup_id)
      manifest_path = backup_manifest_path(backup_id)
      return nil unless File.exist?(manifest_path)

      JSON.parse(File.read(manifest_path), symbolize_names: true)
    end

    def backup_manifest_path(backup_id)
      backup_dir = ensure_backup_directory
      File.join(backup_dir, "#{backup_id}_manifest.json")
    end

    def calculate_file_checksum(filepath)
      Digest::SHA256.file(filepath).hexdigest
    end

    def calculate_backup_size(manifest)
      total_size = 0
      manifest[:components]&.each do |_type, component|
        total_size += component[:size_mb] || 0
      end
      total_size.round(2)
    end
  end
end

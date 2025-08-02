namespace :test do
  desc "Run tests with coverage report and display summary"
  task :coverage do
    ENV["RAILS_ENV"] = "test"

    puts "Running tests with coverage analysis..."
    puts "=" * 80

    # Run tests
    success = system("bundle exec rails test")

    if File.exist?("coverage/.resultset.json")
      require "json"

      # Parse coverage data
      data = JSON.parse(File.read("coverage/.resultset.json"))
      latest_run = data.values.first
      coverage_data = latest_run["coverage"]

      # Calculate coverage by file type
      stats = {
        "Models" => { pattern: /app\/models\/.*\.rb$/, files: [] },
        "Controllers" => { pattern: /app\/controllers\/.*\.rb$/, files: [] },
        "Services" => { pattern: /app\/services\/.*\.rb$/, files: [] },
        "Jobs" => { pattern: /app\/jobs\/.*\.rb$/, files: [] },
        "Components" => { pattern: /app\/components\/.*\.rb$/, files: [] },
        "Channels" => { pattern: /app\/channels\/.*\.rb$/, files: [] },
        "Helpers" => { pattern: /app\/helpers\/.*\.rb$/, files: [] }
      }

      # Process each file
      coverage_data.each do |file, info|
        next unless info["lines"]

        lines = info["lines"]
        covered = lines.compact.count { |n| n.is_a?(Numeric) && n > 0 }
        total = lines.compact.count { |n| n.is_a?(Numeric) }
        next if total == 0

        percentage = (covered.to_f / total * 100).round(2)

        # Categorize file
        stats.each do |category, config|
          if file.match?(config[:pattern])
            config[:files] << {
              path: file.split("/").last(2).join("/"),
              percentage: percentage,
              covered: covered,
              total: total
            }
            break
          end
        end
      end

      # Display results
      puts "\nCoverage Summary by Category:"
      puts "=" * 80

      stats.each do |category, config|
        files = config[:files]
        next if files.empty?

        total_covered = files.sum { |f| f[:covered] }
        total_lines = files.sum { |f| f[:total] }
        category_percentage = total_lines > 0 ? (total_covered.to_f / total_lines * 100).round(2) : 0

        puts "\n#{category}: #{category_percentage}% (#{total_covered}/#{total_lines} lines)"
        puts "-" * 40

        # Show files with lowest coverage first
        files.sort_by { |f| f[:percentage] }.first(5).each do |file|
          status = case file[:percentage]
          when 0 then "❌"
          when 0..50 then "⚠️ "
          when 50..80 then "🟡"
          else "✅"
          end
          puts "  #{status} #{file[:path].ljust(30)} #{file[:percentage].to_s.rjust(6)}%"
        end

        if files.size > 5
          puts "  ... and #{files.size - 5} more files"
        end
      end

      # Overall summary
      puts "\n" + "=" * 80
      if File.exist?("coverage/.last_run.json")
        last_run = JSON.parse(File.read("coverage/.last_run.json"))
        line_coverage = last_run["result"]["line"]
        branch_coverage = last_run["result"]["branch"] || 0

        puts "Overall Line Coverage: #{line_coverage}%"
        puts "Overall Branch Coverage: #{branch_coverage}%"

        if line_coverage < 80
          puts "\n⚠️  Coverage is below 80% target!"
        else
          puts "\n✅ Coverage meets target!"
        end
      end

      puts "\nDetailed report: open coverage/index.html"
    else
      puts "No coverage data found. Make sure SimpleCov is configured."
    end

    exit(1) unless success
  end

  desc "Generate coverage report for a specific file pattern"
  task :coverage_for, [ :pattern ] => :environment do |t, args|
    pattern = args[:pattern] || "test/**/*_test.rb"

    puts "Running tests matching: #{pattern}"
    system("bundle exec rails test #{pattern}")

    Rake::Task["test:coverage_summary"].invoke
  end

  desc "Show coverage summary without running tests"
  task :coverage_summary do
    if File.exist?("coverage/.last_run.json")
      require "json"
      last_run = JSON.parse(File.read("coverage/.last_run.json"))

      puts "\nLast Coverage Run:"
      puts "Line Coverage: #{last_run['result']['line']}%"
      puts "Branch Coverage: #{last_run['result']['branch']}%"
    else
      puts "No coverage data found. Run 'rails test:coverage' first."
    end
  end
end

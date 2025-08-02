class RateLimitingService
  RATE_LIMITS = {
    # General API limits
    "api:general" => { requests: 100, window: 1.minute },
    "api:burst" => { requests: 10, window: 10.seconds },

    # Authentication limits
    "auth:login" => { requests: 5, window: 5.minutes },
    "auth:password_reset" => { requests: 3, window: 1.hour },
    "auth:email_verification" => { requests: 3, window: 1.hour },

    # Claude API limits
    "claude:requests" => { requests: 50, window: 1.minute },
    "claude:heavy" => { requests: 10, window: 1.minute },

    # File operations
    "files:upload" => { requests: 20, window: 1.minute },
    "files:download" => { requests: 100, window: 1.minute },

    # Search and indexing
    "search:requests" => { requests: 60, window: 1.minute },
    "indexing:operations" => { requests: 30, window: 1.minute }
  }.freeze

  class << self
    def check_rate_limit(identifier, action, request_ip = nil)
      key = rate_limit_key(identifier, action, request_ip)
      limit_config = RATE_LIMITS[action]

      return { allowed: true, remaining: Float::INFINITY } unless limit_config

      current_count = get_current_count(key, limit_config[:window])
      max_requests = limit_config[:requests]

      if current_count >= max_requests
        log_rate_limit_exceeded(identifier, action, current_count, max_requests)
        return {
          allowed: false,
          remaining: 0,
          reset_at: get_reset_time(key, limit_config[:window]),
          retry_after: limit_config[:window].to_i
        }
      end

      # Increment counter
      increment_counter(key, limit_config[:window])

      {
        allowed: true,
        remaining: max_requests - current_count - 1,
        reset_at: get_reset_time(key, limit_config[:window])
      }
    end

    def enforce_rate_limit!(identifier, action, request_ip = nil)
      result = check_rate_limit(identifier, action, request_ip)

      unless result[:allowed]
        raise RateLimitExceededError.new(
          "Rate limit exceeded for #{action}",
          retry_after: result[:retry_after],
          reset_at: result[:reset_at]
        )
      end

      result
    end

    def get_rate_limit_headers(identifier, action, request_ip = nil)
      result = check_rate_limit(identifier, action, request_ip)
      limit_config = RATE_LIMITS[action]

      return {} unless limit_config

      {
        "X-RateLimit-Limit" => limit_config[:requests].to_s,
        "X-RateLimit-Remaining" => result[:remaining].to_s,
        "X-RateLimit-Reset" => result[:reset_at]&.to_i&.to_s,
        "X-RateLimit-Window" => limit_config[:window].to_i.to_s
      }.compact
    end

    def clear_rate_limit(identifier, action, request_ip = nil)
      key = rate_limit_key(identifier, action, request_ip)
      Redis.current.del(key)
    end

    private

    def rate_limit_key(identifier, action, request_ip)
      # Include IP address for additional protection against distributed attacks
      base_key = "rate_limit:#{action}:#{identifier}"
      request_ip ? "#{base_key}:#{request_ip}" : base_key
    end

    def get_current_count(key, window)
      # Use Redis sliding window counter
      now = Time.current.to_f
      window_start = now - window.to_f

      # Remove old entries and count current entries
      pipe = Redis.current.pipelined do |redis|
        redis.zremrangebyscore(key, "-inf", window_start)
        redis.zcard(key)
        redis.expire(key, window.to_i + 10) # Add some buffer to expiration
      end

      pipe[1] || 0
    end

    def increment_counter(key, window)
      now = Time.current.to_f

      Redis.current.pipelined do |redis|
        redis.zadd(key, now, "#{now}-#{SecureRandom.hex(4)}")
        redis.expire(key, window.to_i + 10)
      end
    end

    def get_reset_time(key, window)
      # Get the earliest entry in the current window
      earliest_entry = Redis.current.zrange(key, 0, 0, with_scores: true).first
      return nil unless earliest_entry

      Time.at(earliest_entry[1] + window.to_f)
    end

    def log_rate_limit_exceeded(identifier, action, current_count, max_requests)
      Rails.logger.warn(
        "Rate limit exceeded: identifier=#{identifier}, action=#{action}, " \
        "current=#{current_count}, max=#{max_requests}"
      )

      # Track in error tracking system
      ErrorTrackingService.track_business_event("rate_limit_exceeded", {
        identifier: identifier,
        action: action,
        current_count: current_count,
        max_requests: max_requests
      })
    end
  end

  class RateLimitExceededError < StandardError
    attr_reader :retry_after, :reset_at

    def initialize(message, retry_after: nil, reset_at: nil)
      super(message)
      @retry_after = retry_after
      @reset_at = reset_at
    end
  end
end

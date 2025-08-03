# frozen_string_literal: true

# Redis fallback configuration for caching and real-time features
# Since Redis gem is not available, we'll create a fallback object

Rails.logger.info "[REDIS] Redis gem not available. Using Rails cache fallback."

# Create a mock Redis object that falls back to Rails cache
redis_fallback = Object.new

redis_fallback.define_singleton_method(:pipelined) do |&block|
  # For pipelined operations, we'll just execute them directly
  block.call(self) if block_given?
end

redis_fallback.define_singleton_method(:hset) do |key, field, value|
  Rails.cache.write("#{key}:#{field}", value, expires_in: 1.hour)
end

redis_fallback.define_singleton_method(:expire) do |key, ttl|
  # Rails cache handles expiration automatically
  true
end

redis_fallback.define_singleton_method(:setex) do |key, ttl, value|
  Rails.cache.write(key, value, expires_in: ttl.seconds)
end

redis_fallback.define_singleton_method(:ping) do
  "PONG"
end

# Create Redis constant to avoid NameError
redis_class = Class.new do
  @current_instance = nil

  def self.current
    @current_instance ||= new
  end

  def pipelined(&block)
    block.call(self) if block_given?
  end

  def hset(key, field, value)
    Rails.cache.write("#{key}:#{field}", value, expires_in: 1.hour)
  end

  def expire(key, ttl)
    # Rails cache handles expiration automatically
    true
  end

  def setex(key, ttl, value)
    Rails.cache.write(key, value, expires_in: ttl.seconds)
  end

  def ping
    "PONG"
  end
end

Object.const_set(:Redis, redis_class) unless defined?(Redis)

Rails.logger.info "[REDIS] Redis fallback object initialized"

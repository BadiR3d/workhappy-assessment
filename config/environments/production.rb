Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.assume_ssl = true
  config.log_level = :info
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
  config.cache_store = :memory_store
  config.hosts = [ENV.fetch("APP_HOST")]
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")
end

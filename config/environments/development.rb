Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = false
  config.log_level = :info
  config.cache_store = :memory_store
  config.secret_key_base = "development-only-" + "a" * 128
end

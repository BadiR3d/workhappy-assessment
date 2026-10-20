require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"
Bundler.require(*Rails.groups)

module Workhappy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.time_zone = "UTC"
    config.active_record.schema_format = :sql
    config.autoload_lib(ignore: %w[tasks])
    config.filter_parameters += [/.*/]
    # Rails' request-start line contains the raw query string, outside parameter filtering.
    config.middleware.delete Rails::Rack::Logger
    config.log_tags = [:request_id]
    config.action_dispatch.cookies_same_site_protection = :lax
    config.session_store :cookie_store, key: "_workhappy_session", expire_after: 8 * 60 * 60,
      httponly: true, same_site: :lax, secure: Rails.env.production?
    config.public_file_server.enabled = true
    config.action_dispatch.default_headers.merge!(
      # Native form POSTs need a same-origin Origin for Rails' CSRF origin check.
      # Cross-origin destinations still receive no Referer under this policy.
      "Referrer-Policy" => "same-origin",
      "X-Content-Type-Options" => "nosniff",
      "X-Frame-Options" => "DENY"
    )
  end
end

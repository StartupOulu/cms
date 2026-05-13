# config/puma.rb

if ENV.fetch("RAILS_ENV", nil) == "production"
  environment ENV.fetch("RAILS_ENV") { "production" }
  directory '/var/www/apps/cms/current'

  # Set up socket and pid files
  bind "unix:///var/www/apps/cms/tmp/sockets/puma.sock"
  pidfile "/var/www/apps/cms/tmp/pids/puma.pid"
  state_path "/var/www/apps/cms/tmp/pids/puma.state"

  # Logging
  stdout_redirect "/var/www/apps/cms/logs/puma.stdout.log",
                  "/var/www/apps/cms/logs/puma.stderr.log",
                  true

  # Preload app for better performance
  preload_app!

  # Handle worker boot
  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  # Specify the PID file. Defaults to tmp/pids/server.pid in development.
  # In other environments, only set the PID file if requested.
  pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

  # Allow puma to be restarted by `bin/rails restart` command.
  plugin :tmp_restart

  # Run the Solid Queue supervisor inside of Puma for single-server deployments
  plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

  # Workers (processes)
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
end

# Threading configuration
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 4000)
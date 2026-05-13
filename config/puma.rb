threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

if ENV.fetch("RAILS_ENV", nil) == "production"
  environment "production"
  directory "/var/www/apps/cms/current"

  bind     "unix:///var/www/apps/cms/tmp/sockets/puma.sock"
  pidfile  "/var/www/apps/cms/tmp/pids/puma.pid"
  state_path "/var/www/apps/cms/tmp/pids/puma.state"

  stdout_redirect "/var/www/apps/cms/logs/puma.stdout.log",
                  "/var/www/apps/cms/logs/puma.stderr.log",
                  true

  workers ENV.fetch("WEB_CONCURRENCY", 1)

  preload_app!

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  # Solid Queue runs inside Puma on this single-server setup.
  # Set SOLID_QUEUE_IN_PUMA=1 in the systemd service file.
  plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
end

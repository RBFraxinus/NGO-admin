# require "rvm/capistrano"
# default_run_options[:pty] = true
set :rbenv_type, :user
set :rbenv_ruby, '1.8.7-p384'
set :default_stage, "production"
set :default_environment, {
  'PATH' => '/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin/rbenv:/home/deploy/.nvm/v0.10.29/bin/npm:/home/deploy/.nvm/v0.10.29/bin/node:/home/deploy/.nvm/v0.10.29/bin/bower:$PATH'
}
role :app, "52.179.82.220"
role :web, "52.179.82.220"
role :db, "52.179.82.220"

server '52.179.82.220', :web, :app, :db, :primary => true


desc "Restart Application"
deploy.task :restart, :roles => [:app] do
  run "touch #{current_path}/tmp/restart.txt"
  run "#{sudo} /etc/init.d/memcached force-reload"
end

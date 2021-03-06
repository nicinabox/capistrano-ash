# Require our base library.
require 'ash/base'
require 'railsless-deploy'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)

configuration.load do
  
# --------------------------------------------
# Setting defaults
# --------------------------------------------
set :uploads_path, "wp-content/uploads"

# --------------------------------------------
# Calling our Methods
# --------------------------------------------
after "deploy:setup", "deploy:setup_shared"
after "deploy:symlink", "wordpress:symlink"
after "ash:fixperms", "wordpress:protect"

# --------------------------------------------
# Overloaded Methods
# --------------------------------------------
namespace :deploy do
  desc "Setup shared application directories and permissions after initial setup"
  task :setup_shared, :roles => :web do
    # remove Capistrano specific directories
    run "rm -Rf #{shared_path}/log"
    run "rm -Rf #{shared_path}/pids"
    run "rm -Rf #{shared_path}/system"
    
    # create shared directories
    run "mkdir -p #{shared_path}/uploads"
    run "mkdir -p #{shared_path}/cache"

    # set correct permissions
    run "chmod -R 777 #{shared_path}/*"
  end

  desc "[internal] Touches up the released code. This is called by update_code after the basic deploy finishes."
  task :finalize_update, :roles => :web, :except => { :no_release => true } do
    # remove shared directories
    run "rm -Rf #{latest_release}/#{uploads_path}"
    run "rm -Rf #{latest_release}/wp-content/cache"
    
    # Removing cruft files.
    run "rm -Rf #{latest_release}/license.txt"
    run "rm -Rf #{latest_release}/readme.html"
  end
end

# --------------------------------------------
# Wordpress-specific methods
# --------------------------------------------  
namespace :wordpress do
  desc "Links the correct settings file"
  task :symlink, :roles => :web, :except => { :no_release => true } do
    run "ln -nfs #{shared_path}/uploads #{current_release}/#{uploads_path}"
    run "ln -nfs #{shared_path}/cache #{current_release}/wp-content/cache"
    run "ln -nfs #{latest_release}/wp-config.php.#{stage} #{latest_release}/wp-config.php"
  end
  
  desc "Set URL in database"
  task :updatedb, :roles => :db, :except => { :no_release => true } do
    run "mysql -u #{dbuser} -p #{dbpass} #{dbname} -e 'UPDATE #{dbprefix}options SET option_value = \"#{application}\" WHERE option_name = \"siteurl\" OR option_name = \"home\"'"
  end
  
  desc "Protect system files"
  task :protect, :except => { :no_release => true } do
    run "chmod 440 #{latest_release}/wp-config.php*"
  end
end    

end
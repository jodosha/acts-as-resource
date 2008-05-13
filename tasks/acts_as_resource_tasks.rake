#ActsAsResource tasks
require 'rake/testtask'
require 'rake/rdoctask'
require 'rubygems'
require 'active_record'
require 'active_record/fixtures'

rails_root		   = File.expand_path(RAILS_ROOT)
path_to_database = File.join(rails_root,  'config', 'database.yml')
plugin_root      = File.join(rails_root,  'vendor', 'plugins', 'acts_as_resource')
path_to_fixtures = File.join(plugin_root, 'test',   'fixtures')
fixtures = %w(bunnies carrots)

require File.join(plugin_root, 'test', 'test_helper')

desc "Default task (test)."
task :resource => [ 'resource:test' ]

namespace :resource do
  desc "ActsAsResource tests."
  task :test => [ 'resource:db:prepare', 'resource:db:connect', 'resource:test:all' ]
  
  namespace :test do
    desc "ActsAsResource tests (don't call directly)."
    Rake::TestTask.new(:all) do |t|
      t.libs   << "#{plugin_root}/lib"
      t.pattern = "#{plugin_root}/test/**/*_test.rb"
      t.verbose = true
    end
  end
  
  namespace :db do
    desc "Connect to the plugin test database."
    task :connect do
      ENV['RAILS_ENV'] ||= 'test'
      ActiveRecord::Base.configurations = YAML::load_file(path_to_database)
      ActiveRecord::Base.establish_connection ENV['RAILS_ENV']
    end
    
    desc "Prepare testing database."
    task :prepare => [ 'resource:db:create', 'resource:fixtures:load' ]
    
    desc "Create schema for testing database."
    task :create => [ 'resource:db:connect' ] do
      ActiveRecord::Schema.define do
        create_table :bunnies, :force => true do |t|
          t.column :first_name, :string, :null => false
          t.column :last_name,  :string, :null => false
        end

        create_table :carrots, :force => true do |t|
          t.column :bunny_id,  :integer, :null => false
          t.column :color,     :string,  :null => false, :default => ''
        end        
      end      
    end
    
    desc "Delete schema for testing database."
    task :delete => [ 'resource:db:connect' ] do
      ActiveRecord::Schema.define do
        drop_table :carrots
        drop_table :bunnies
      end
    end
  end  
  
  namespace :fixtures do
    desc "Load fixtures."
    task :load => [ 'resource:db:connect' ] do
      fixtures.each { |f| Fixtures.create_fixtures(path_to_fixtures, f) }
    end
  end
end
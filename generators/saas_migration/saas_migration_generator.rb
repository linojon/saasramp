class SaasMigrationGenerator < Rails::Generator::NamedBase
  def initialize(runtime_args, runtime_options = {})
    runtime_args.insert(0, 'migrations')
    super
  end

  def manifest
    record do |m|
      m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_subscription_etc"
    end
  end
end
# adapted from Ryan Bates nifty generators

Rails::Generator::Commands::Create.class_eval do
  def route_resources_x(resource, options)
    resource_list = [resource.to_sym.inspect, options.inspect].join(', ')
    sentinel = 'ActionController::Routing::Routes.draw do |map|'
    
    logger.route "map.resources #{resource_list}"
    unless options[:pretend]
      gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
        "#{match}\n  map.resources #{resource_list}\n"
      end
    end
  end
  
  def insert_into(file, line)
    logger.insert "#{line} into #{file}"
    unless options[:pretend]
      gsub_file file, /^(class|module) .+$/ do |match|
        "#{match}\n  #{line}"
      end
    end
  end
  
end

Rails::Generator::Commands::Destroy.class_eval do
  def route_resources_x(resource, options)
    resource_list = [resource.to_sym.inspect, options.inspect].join(', ')
    look_for = "\n  map.resources #{resource_list}\n"
    logger.route "map.resources #{resource_list}"
    unless options[:pretend]
      gsub_file 'config/routes.rb', /(#{look_for})/mi, ''
    end
  end

  def insert_into(file, line)
    logger.remove "#{line} from #{file}"
    unless options[:pretend]
      gsub_file file, "\n  #{line}", ''
    end
  end
end

Rails::Generator::Commands::List.class_eval do
  def route_resources_x(resource, options)
    resource_list = [resource.to_sym.inspect, options.inspect].join(', ')
    logger.route "map.resources #{resource_list}"
  end

  def insert_into(file, line)
    logger.insert "#{line} into #{file}"
  end
end

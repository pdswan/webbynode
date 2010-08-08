module Webbynode::Commands
  class Init < Webbynode::Command
    summary "Prepares the application on current folder for deployment"
    parameter :webby, String, "Name or IP of the Webby to deploy to", :required => false
    option :dns, String, "The DNS used for this application"
    option :adddns, "Creates the DNS entries for the domain"
    option :port, "Specifies an alternate SSH port to connect to Webby", :validate => :integer
    option :engine, "Sets the application engine for the app", :validate => { :in => ['php', 'rack', 'rails', 'rails3'] }
    
    def execute
      unless params.any?
        io.log help
        return
      end

      check_prerequisites

      webby       = param(:webby)
      app_name    = io.app_name
      git_present = git.present?

      if option(:dns)
        dns_entry = "#{option(:dns)}" 
      else
        dns_entry = app_name
      end

      if git_present and !git.clean?
        raise CommandError, 
          "Cannot initialize: git has pending changes. Execute a git commit or add changes to .gitignore and try again."
      end
      
      io.log "Initializing application #{app_name} #{dns_entry ? "with dns #{dns_entry}" : ""}", :start
      
      detect_engine
      
      webby_ip = get_ip(webby)
      
      io.log ""
      io.log "Initializing directory structure..."
      
      if pushand_exists = io.file_exists?(".pushand")
        io.log ""
        io.log "It seems this application was initialized before."
        overwrite = ask('Do you want to initialize it again (y/n)?').downcase == 'y'
      end
      
      if overwrite || !pushand_exists
        io.log ""
        io.create_file(".pushand", "#! /bin/bash\nphd $0 #{app_name} #{dns_entry}\n", true)
      end

      create_webbynode_tree

      unless git_present
        io.log "Initializing git and applying initial commit..."
        git.init 
        git.add "." 
        git.commit "Initial commit"
      end
      
      if git.remote_exists?('webbynode')
        io.log ""
        io.log "Webbynode git integration already initialized."
        if overwrite || ask('Do you want to overwrite the current settings (y/n)?').downcase == 'y'
          git.delete_remote('webbynode')
        end
        io.log ""
      end
      
      if overwrite or (!git.remote_exists?('webbynode') and git_present)
        io.log "Commiting Webbynode changes..."
        git.add "." 
        git.commit2 "[Webbynode] Rapid App Deployment Reinitialization"
      end
      
      io.log "Adding webbynode as git remote..."
      options = ["webbynode", webby_ip, app_name]
      options << option(:port).to_i if option(:port)

      Webbynode::Server.new(webby_ip).add_ssh_key LocalSshKey, nil

      git.add_remote *options
      
      handle_dns option(:dns) if option(:adddns)
      
      io.log "Application #{app_name} ready for Rapid Deployment", :finish
    rescue Webbynode::InvalidAuthentication
      io.log "Could not connect to webby: invalid authentication.", true

    rescue Webbynode::PermissionError
      io.log "Could not create an SSH key: permission error.", true

    rescue Webbynode::GitRemoteAlreadyExistsError
      io.log "Application already initialized."
    end
    
    private
    
    def get_ip(webby)
      return webby if webby =~ /\b(?:\d{1,3}\.){3}\d{1,3}\b/
        
      api_webbies = api.webbies
      
      unless webby
        # TODO: raise CommandError id size = 0
        if api_webbies.keys.size == 1
          webby = api_webbies[api_webbies.keys.first]
        else
          io.log ""
          io.log "Current Webbies in your account:"
          io.log ""
        
          choices = []
          api_webbies.keys.sort.each_with_index do |webby_key, i|
            webby = api_webbies[webby_key]
            choices << webby
            io.log "  #{i+1}. #{webby['name']} (#{webby['ip']})"
          end
        
          io.log "", :simple
          choice = ask("Which Webby do you want to deploy to:", Integer) { |q| q.in = 1..(api_webbies.size+1) }
          webby  = choices[choice-1]
        end
        
        io.log "", :simple
        io.log "Set deployment Webby to #{webby['name']}."
        
        return webby['ip']
      end

      io.log "Retrieving IP for Webby #{webby}..."
      webby_ip = api.ip_for(webby)

      unless webby_ip
        if (webbies = api_webbies.keys) and webbies.any?
          raise CommandError, 
            "Couldn't find Webby '#{webby}' on your account. Your Webbies are: #{webbies.map { |w| "'#{w}'"}.to_phrase}."
        else
          raise CommandError, "You don't have any active Webbies on your account."
        end
      end
      
      webby_ip
    end
    
    def detect_engine
      if option(:engine)
        engine = Webbynode::Engines.find(option(:engine)) 
        io.log "Engine '#{option(:engine)}' is invalid." unless engine
      end
      
      engine ||= resolve_engine  
      engine.new.prepare
      
      io.add_setting "engine", engine.engine_id
    end
    
    def resolve_engine
      engine = Webbynode::Engines.detect
      engine ||= choose_engine
    end
    
    def choose_engine
      io.log ""
      io.log "Supported engines:"
      io.log ""
      
      engines = Webbynode::Engines::All
      engines.each_with_index do |engine, i|
        io.log "  #{i+1}. #{engine.engine_name.split('::').last}"
      end
      
      io.log ""

      choice = ask("Select the engine your app uses:", Integer) { |q| q.in = 1..(engines.size+1) }
      engine = engines[choice-1]
      
      io.log ""
      io.log "Initializing with #{engine.engine_name} engine..."
      
      engine
    end
    
    def check_prerequisites
      unless io.exec_in_path?('git')
        raise CommandError, <<-EOS 
Error: git not found on current path.

In order to use Webbynode Gem for deployment, you must have git installed.
For more information about installing git: http://book.git-scm.com/2_installing_git.html
EOS
      end
    end
    
    def create_webbynode_tree
      io.mkdir(".webbynode/tasks")
      
      io.create_if_missing(".webbynode/tasks/after_push", "")
      io.create_if_missing(".webbynode/tasks/before_push", "")
      io.create_if_missing(".webbynode/aliases", "")
      io.create_if_missing(".webbynode/config", "")
    end
  end
end
module Webbynode
  class InvalidAuthentication < StandardError; end
  class PermissionError < StandardError; end
  
  class Server
    attr_accessor :ip
    
    def initialize(ip)
      @ssh = Ssh.new(ip)
    end
    
    def io
      @io ||= Io.new
    end
   
    def remote_executor
      @remote_executor ||= RemoteExecutor.new(ip)
    end

    def add_ssh_key(key_file, passphrase="")
      io.create_local_key(key_file, passphrase) unless io.file_exists?(key_file)
      remote_executor.create_folder("~/.ssh", "700")
      
      key_contents = io.read_file(key_file)
      remote_executor.exec "echo \"#{key_contents}\" >> ~/.ssh/authorized_keys; chmod 644 ~/.ssh/authorized_keys"
    end
  end
end
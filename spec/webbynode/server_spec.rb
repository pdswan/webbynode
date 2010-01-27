# Load Spec Helper
require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'spec_helper')

describe Webbynode::Server do
  it "should have an Io instance" do
    Webbynode::Server.new("1.2.3.4").io.class.should == Webbynode::Io
  end

  it "should have a RemoteExecutor instance" do
    Webbynode::Server.new("1.2.3.4").remote_executor.class.should == Webbynode::RemoteExecutor
  end

  describe "#add_ssh_key" do
    before(:each) do
      @io = mock("Io")
      @io.as_null_object
    
      @re = mock("RemoteExecutor")
      @re.as_null_object
      
      @pushand = mock("PushAnd")
      @pushand.as_null_object
    
      @server = Webbynode::Server.new("1.2.3.4")
      @server.should_receive(:io).any_number_of_times.and_return(@io)
      @server.should_receive(:remote_executor).any_number_of_times.and_return(@re)
      @server.should_receive(:pushand).any_number_of_times.and_return(@pushand)
    end
  
    describe "which local key missing" do
      context "when unsuccessful" do
        it "should create a local SSH key with empty passphrase" do
          @io.should_receive(:file_exists?).with("xyz").and_return(false)
          @io.should_receive(:create_local_key).with("xyz", "")
      
          @server.add_ssh_key "xyz"
        end

        it "should create a local SSH key with the provided passphrase" do
          @io.should_receive(:file_exists?).with("abc").and_return(false)
          @io.should_receive(:create_local_key).with("abc", "my_passphrase")
      
          @server.add_ssh_key "abc", "my_passphrase"
        end
      end
      
      context "when unsuccessful" do
        it "should raise a PermissionError if cannot write the key" do
          @io.should_receive(:file_exists?).with("xyz").and_return(false)
          @io.should_receive(:create_local_key).and_raise(Webbynode::PermissionError)

          lambda { @server.add_ssh_key "xyz" }.should raise_error(Webbynode::PermissionError)
        end
      end
    end
    
    describe "with local key present" do
      context "when successful" do
        it "should not create a local key" do
          @io.should_receive(:file_exists?).with("xyz").and_return(true)
          @io.should_receive(:create_local_key).never()
          
          @server.add_ssh_key "xyz"
        end
        
        it "should create the SSH folder on the server" do
          @re.should_receive(:create_folder).with("~/.ssh")
          @server.add_ssh_key "abc"
        end

        it "should upload the local key to the server" do
          @io.should_receive(:read_file).with("abc").and_return("key_contents")
          @re.should_receive(:exec).with('echo "key_contents" >> ~/.ssh/authorized_keys; chmod 644 ~/.ssh/authorized_keys')

          @server.add_ssh_key "abc"
        end
      end
    end
    
    describe "#application_pushed?" do
      context "when successful" do
        it "should check if the application has been pushed" do
          @pushand.should_receive(:parse_remote_app_name).and_return('test.webbynode.com')
          @re.should_receive(:exec).with("cd test.webbynode.com")
          @server.application_pushed?
        end
      end
      
      context "when unsuccessful" do
        it "should check if the application has been pushed" do
          @pushand.should_receive(:parse_remote_app_name).and_return('test.webbynode.com')
          error_message = "bash: line 0: cd: test.webbynode.com: No such file or directory"
          @re.should_receive(:exec).with("cd test.webbynode.com").and_return(error_message)
          error_message.should =~ /No such file or directory/
          @server.application_pushed?
        end
      end
    end
    
  end
end

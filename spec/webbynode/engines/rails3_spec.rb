# Load Spec Helper
require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'spec_helper')

describe Webbynode::Engines::Rails3 do
  let(:io) { double("io").as_null_object }

  subject do
    Webbynode::Engines::Rails3.new.tap do |engine|
      engine.stub!(:io).and_return(io)
    end
  end
  
  describe 'class methods' do
    subject { Webbynode::Engines::Rails3 }

    its(:engine_id)    { should == 'rails3' }
    its(:engine_name)  { should == 'Rails 3' }
    its(:git_excluded) { should == ["config/database.yml"] } #, "db/schema.rb"] }
  end
  
  describe '#prepare' do
    let(:gemfile) { double('gemfile').as_null_object }
    
    it "complains if there is a sqlite3-ruby dependency outside of development and test groups in Gemspec" do
      gemfile.should_receive(:present?).and_return(true)
      gemfile.should_receive(:dependencies).and_return(['sqlite3-ruby', 'mysql'])

      subject.stub!(:gemfile).and_return(gemfile)
      lambda { subject.prepare }.should raise_error(Webbynode::Command::CommandError)
    end
  end
  
  describe '#detect' do
    it "if script/rails exists" do
      io.stub!(:file_exists?).with('script/rails').and_return(true)
      
      subject.should be_detected
    end

    it "fails if script/rails doesn't exist" do
      io.stub!(:file_exists?).with('script/rails').and_return(false)
      
      subject.should_not be_detected
    end
  end
end

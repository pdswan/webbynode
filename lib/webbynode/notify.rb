module Webbynode

  class Notify
    
    TITLE       = "Webbynode"
    IMAGE_PATH  = File.join(File.dirname(__FILE__), '..', '..', 'assets', 'webbynode.png')
    
    def self.message(message)
      if self.installed? and !$testing
        %x(growlnotify -t "#{TITLE}" -m "#{message}" --image "#{IMAGE_PATH}")
      end
    end
    
    def self.installed?
      @installed ||= Io.new.exec_in_path?("growlnotify")
    end
    
  end
end
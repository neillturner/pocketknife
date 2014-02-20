class Pocketknife
  # == Node
  #
  # A node represents a remote computer that will be managed with Pocketknife and <tt>chef-solo</tt>. It can connect to a node, execute commands on it, install the stack, and upload and apply configurations to it.
  class Node
    # String name of the node.
    attr_accessor :name

    # Instance of a {Pocketknife}.
    attr_accessor :pocketknife

    # Instance of Rye::Box connection, cached by {#connection}.
    attr_accessor :connection_cache

    # Hash with information about platform, cached by {#platform}.
    attr_accessor :platform_cache
    
    @sudo = ""
	@deleterepo = false
	@noupdatepackages = false
	@xoptions = ""
	@foodcritic = ""
	@rspec = ""
	@why_run = ""
	@log_location = '/var/local/pocketknife'
	
    # Initialize a new node.
    #
    # @param [String] name A node name.
    # @param [Pocketknife] pocketknife
    def initialize(name, pocketknife)
      self.name = name
      self.pocketknife = pocketknife
      if pocketknife.user != nil and pocketknife.user != "" and pocketknife.user != "root"
	     if pocketknife.sudo_password != nil and pocketknife.sudo_password != ""
			@sudo = "echo #{pocketknife.sudo_password} | sudo -S "
		 else
           @sudo = "sudo "
		 end
      end
	  @deleterepo = false
	  @noupdatepackages = false
	  if pocketknife.deleterepo != nil and pocketknife.deleterepo == true	  
         @deleterepo =true
      end
	  if pocketknife.noupdatepackages != nil and pocketknife.noupdatepackages == true	  
         @noupdatepackages =true
      end	  
	  if pocketknife.xoptions != nil and pocketknife.xoptions != ""	  
         @xoptions = pocketknife.xoptions
      end	  
 	  if pocketknife.why_run != nil and pocketknife.why_run == true	  
         @why_run ="--why-run"
      end
	  if pocketknife.foodcritic != nil and pocketknife.foodcritic != ""
   	     @foodcritic = VAR_POCKETKNIFE + pocketknife.foodcritic
      end
	  if pocketknife.rspec != nil and pocketknife.rspec != ""
   	     @rspec = VAR_POCKETKNIFE + pocketknife.rspec
      end
 	  self.connection_cache = nil
	  @log_location = '/var/local/pocketknife'
    end	

    # Returns a Rye::Box connection.
    #
    # Caches result to {#connection_cache}.
 	def connection
      return self.connection_cache ||= begin
          #rye = Rye::Box.new(self.name, :user => "root")
          user = "root"
		  password = ""
          if self.pocketknife.user != nil and self.pocketknife.user != ""
             user = self.pocketknife.user
          end
		  if self.pocketknife.local_port != nil and self.pocketknife.local_port != ""
             if self.pocketknife.ssh_key != nil and self.pocketknife.ssh_key != ""
                puts "*** Connecting to ssh tunnel ..... via localhost port #{self.pocketknife.local_port} as user #{user} with ssh key *** "
                rye = Rye::Box.new("localhost", {:user => user, :port => self.pocketknife.local_port, :keys => self.pocketknife.ssh_key, :safe => false })  
             else
                puts "*** Connecting to ssh tunnel ..... via localhost port #{self.pocketknife.local_port} as user #{user} *** "
                 rye = Rye::Box.new("localhost", {:user => user, :password => self.pocketknife.password, :port => self.pocketknife.local_port, :safe => false })
             end
          elsif self.pocketknife.ssh_key != nil and self.pocketknife.ssh_key != ""
             puts "*** Connecting to .... #{self.name} as user #{user} with ssh key *** "
             rye = Rye::Box.new(self.name, {:user => user, :keys => self.pocketknife.ssh_key, :safe => false })
          else
             puts "*** Connecting to .... #{self.name} as user #{user} *** "
             rye = Rye::Box.new(self.name, {:user => user, :password => self.pocketknife.password })
          end
          rye.disable_safe_mode
          rye
        end
    end

    # Displays status message.
    #
    # @param [String] message The message to display.
    # @param [Boolean] importance How important is this? +true+ means important, +nil+ means normal, +false+ means unimportant.
    def say(message, importance=nil)
      self.pocketknife.say("* #{self.name}: #{message}", importance)
    end

    # Returns path to this node's <tt>nodes/NAME.json</tt> file, used as <tt>node.json</tt> by <tt>chef-solo</tt>.
    #
    # @return [Pathname]
    def local_node_json_pathname
      return Pathname.new("nodes") + "#{self.name}.json"
    end

    # Does this node have the given executable?
    #
    # @param [String] executable A name of an executable, e.g. <tt>chef-solo</tt>.
    # @return [Boolean] Has executable?
    def has_executable?(executable)
      begin
        self.connection.execute(%{which "#{executable}" && test -x `which "#{executable}"`})
        return true
      rescue Rye::Err
        return false
      end
    end

    # Returns information describing the node.
    #
    # The information is formatted similar to this:
    #   {
    #     :distributor=>"Ubuntu", # String with distributor name
    #     :codename=>"maverick", # String with release codename
    #     :release=>"10.10", # String with release number
    #     :version=>10.1 # Float with release number
    #   }
    #
    # @return [Hash<String, Object] Return a hash describing the node, see above.
    # @raise [UnsupportedInstallationPlatform] Raised if there's no installation information for this platform.
    def platform
      puts "*** platform cache #{self.platform_cache} "
       result = {}
       begin
         output = self.connection.cat("/etc/centos-release").to_s
         if output != nil and output != "" 
            result[:distributor]="centos"
            return result
         end
       rescue 
       end
       begin
         output = self.connection.cat("/etc/redhat-release").to_s
         if output != nil and output != ""              
            result[:distributor]="red hat" 
            return result
         end         
       rescue 
       end
       begin
         # amazon linux is red hat
         output = self.connection.cat("/etc/system-release").to_s
         if output != nil and output != "" and output.include? "Amazon Linux" 
            result[:distributor]="red hat" 
            return result
         end         
       rescue 
       end         
      lsb_release = "/etc/lsb-release"
      puts "*** lsb_release #{lsb_release}"
      return self.platform_cache ||= begin
        begin
          output = self.connection.cat(lsb_release).to_s
          result = {}
          result[:distributor] = output[/DISTRIB_ID\s*=\s*(.+?)$/, 1]
          result[:release] = output[/DISTRIB_RELEASE\s*=\s*(.+?)$/, 1]
          result[:codename] = output[/DISTRIB_CODENAME\s*=\s*(.+?)$/, 1]
          result[:version] = result[:release].to_f
          puts "*** output #{output}"
          puts "*** result #{result}"
          if result[:distributor] && result[:release] && result[:codename] && result[:version]
            return result
          else
            raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' with invalid '/etc/lsb-release' file", self.name)
          end
        rescue Rye::Err
          raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' without '/etc/lsb-release'", self.name)
        end
      end
    end

    # Installs Chef and its dependencies on a node if needed.
    #
    # @raise [NotInstalling] Raised if Chef isn't installed, but user didn't allow installation.
    # @raise [UnsupportedInstallationPlatform] Raised if there's no installation information for this platform.
    def install
	  if @noupdatepackages == nil or @noupdatepackages != true
	    self.install_packages
	  end	
	  self.execute("#{@sudo} source /etc/profile.d/rvm.sh", true) if pocketknife.rvm != nil and pocketknife.rvm == true
      unless self.has_executable?("chef-solo")
        case self.pocketknife.can_install
        when nil
          # Prompt for installation
          print "? #{self.name}: Chef not found. Install it and its dependencies? (Y/n) "
          STDOUT.flush
          answer = STDIN.gets.chomp
          case answer
          when /^y/i, ''
            # Continue with install
          else
            raise NotInstalling.new("Chef isn't installed on node '#{self.name}', but user doesn't want to install it.", self.name)
          end
        when true
          # User wanted us to install
        else
          # Don't install
          raise NotInstalling.new("Chef isn't installed on node '#{self.name}', but user doesn't want to install it.", self.name)
        end

        unless self.has_executable?("ruby")
          self.install_ruby
        end

        self.install_chef
      end
	  unless self.has_executable?("berks")
         self.install_berkshelf
      end
    end

    # Installs Chef on the remote node.
    def install_chef
      chef_version = ""
      chef_version = "-v #{self.pocketknife.chef_version}" if self.pocketknife.chef_version != nil and self.pocketknife.chef_version != "" and self.pocketknife.chef_version != "latest"
      self.say("*** Installing chef #{chef_version} ***")
      self.execute("#{@sudo} gem install --no-rdoc --no-ri #{chef_version} chef -V", true)
      self.say("Installed chef", false)
    end

 
    # Installs Ruby on the remote node.
    def install_ruby
        case self.platform[:distributor].downcase
        when /ubuntu/, /debian/, /gnu\/linux/
          # ruby 1.8
          #"DEBIAN_FRONTEND=noninteractive sudo apt-get --yes install ruby ruby-dev libopenssl-ruby irb build-essential wget ssl-cert"
          # ruby 1.9.1
          command = "DEBIAN_FRONTEND=noninteractive #{@sudo} apt-get --yes install ruby1.9.1 ruby1.9.1-dev libopenssl-ruby1.9.1 irb1.9.1 build-essential wget ssl-cert rubygems"
        when /centos/, /red hat/, /scientific linux/
		  if pocketknife.rvm != nil and pocketknife.rvm == true
             command   <<-HERE
#{@sudo} yum -y install gcc-c++ patch readline readline-devel zlib zlib-devel &&
#{@sudo} yum -y install libyaml-devel libffi-devel openssl-devel make &&
#{@sudo} yum -y install bzip2 autoconf automake libtool bison iconv-devel &&
#{@sudo} curl -L get.rvm.io | bash -s stable &&
#{@sudo} source /etc/profile.d/rvm.sh &&
#{@sudo} rvm install 1.9.3 &&
#{@sudo} rvm use 1.9.3 --default &&
#{@sudo} ruby --version	
  HERE  	 
		  else 
             command = "#{@sudo}yum -y install ruby ruby-shadow gcc gcc-c++ ruby-devel rubygems wget"
		  end
       else
          raise UnsupportedInstallationPlatform.new("Can't install on node '#{self.name}' with unknown distrubtor: `#{self.platform[:distrubtor]}`", self.name)
        end

       self.say("*** Installing ruby *** ")
       if command != ""
         self.say("*** #{command} ***", false)
         self.execute(command, true)
         self.say("*** Installed ruby ***", false)
       end
	end   

	# Installs berkshelf on the remote node.
    def install_berkshelf
      self.say("*** Installing berkshelf ***")
      self.execute <<-HERE
      #{@sudo} gem install berkshelf -V 
    HERE
      self.say("Installed berkshelf", false)
    end	
	
	# Installs chefspec on the remote node.
    def install_chefspec
      self.say("*** Installing chefspec ***")
      self.execute <<-HERE
      #{@sudo} gem install chefspec fauxhai  
    HERE
      self.say("Installed chefspec", false)
    end
	
	# Installs foodcritic on the remote node.
    def install_foodcritic
      self.say("*** Installing foodcritic needs ruby 1.9.2+ ***")
     case self.platform[:distributor].downcase
        when /ubuntu/, /debian/, /gnu\/linux/
        self.execute <<-HERE
    #{@sudo} apt-get -y install libxslt-dev libxml2-dev &&
    #{@sudo} gem install foodcritic
    HERE
      else
         self.execute <<-HERE
    #{@sudo} yum install -y libxml2 libxml2-devel &&
    #{@sudo} gem install foodcritic
     HERE
	  end	  
       self.say("Installed foodcritic", false)
    end	
	
    def install_packages
      self.say("*** Installing packages ***")
      case self.platform[:distributor].downcase
        when /ubuntu/, /debian/, /gnu\/linux/
        self.execute <<-HERE
    #{@sudo} apt-get -y update &&
    #{@sudo} apt-get -y upgrade
    HERE
      else
         self.execute <<-HERE
    #{@sudo}yum -y update
     HERE
	  end
      self.say("Updated Packages", false)
    end  		

    # Prepares an upload, by creating a cache of shared files used by all nodes.
    #
    # IMPORTANT: This will create files and leave them behind. You should use the block syntax or manually call {cleanup_upload} when done.
    #
    # If an optional block is supplied, calls {cleanup_upload} automatically when done. This is typically used like:
    #
    #   Node.prepare_upload do
    #     mynode.upload
    #   end
    #
    # @yield [] Prepares the upload, executes the block, and cleans up the upload when done.
    def self.prepare_upload(&block)
      begin
        puts("********************** ")
        puts("*** Prepare upload *** ")
        puts("********************** ")
        # TODO either do this in memory or scope this to the PID to allow concurrency
        TMP_SOLO_RB.open("w") {|h| h.write(SOLO_RB_CONTENT)}
        TMP_CHEF_SOLO_APPLY.open("w") {|h| h.write(CHEF_SOLO_APPLY_CONTENT)}
        # minitar gem on windows tar file corrupt so use alternative command
        if RUBY_PLATFORM.index("mswin") != nil or RUBY_PLATFORM.index("i386-mingw32") != nil
           puts "*** On windows using tar.exe *** "
           puts "#{ENV['POCKETKNIFE_HOME']}/tar/tar.exe cvf *.*" 
           system "#{ENV['POCKETKNIFE_HOME']}/tar/tar.exe cvf #{TMP_TARBALL.to_s} *.*" 			   
           #puts "#{ENV['POCKETKNIFE_HOME']}/tar/tar.exe cvf #{TMP_TARBALL.to_s} #{VAR_POCKETKNIFE_COOKBOOKS.basename.to_s} #{VAR_POCKETKNIFE_SITE_COOKBOOKS.basename.to_s} #{VAR_POCKETKNIFE_ROLES.basename.to_s} #{VAR_POCKETKNIFE_DATA_BAGS.basename.to_s} #{TMP_SOLO_RB.to_s} #{TMP_CHEF_SOLO_APPLY.to_s}  #{VAR_POCKETKNIFE_BERKSFILE.basename.to_s}" 
           #system "#{ENV['POCKETKNIFE_HOME']}/tar/tar.exe cvf #{TMP_TARBALL.to_s} #{VAR_POCKETKNIFE_COOKBOOKS.basename.to_s} #{VAR_POCKETKNIFE_SITE_COOKBOOKS.basename.to_s} #{VAR_POCKETKNIFE_ROLES.basename.to_s} #{VAR_POCKETKNIFE_DATA_BAGS.basename.to_s} #{TMP_SOLO_RB.to_s} #{TMP_CHEF_SOLO_APPLY.to_s} #{VAR_POCKETKNIFE_BERKSFILE.basename.to_s}" 
        else
           TMP_TARBALL.open("w") do |handle|
             Archive::Tar::Minitar.pack(
              [
               VAR_POCKETKNIFE_COOKBOOKS.basename.to_s,
               VAR_POCKETKNIFE_SITE_COOKBOOKS.basename.to_s,
               VAR_POCKETKNIFE_ROLES.basename.to_s,
               VAR_POCKETKNIFE_DATA_BAGS.basename.to_s,
               TMP_SOLO_RB.to_s,
               TMP_CHEF_SOLO_APPLY.to_s,
			   VAR_POCKETKNIFE_BERKSFILE.basename.to_s
              ],
              handle
             )
           end  
        end
      rescue Exception => e
        cleanup_upload
        raise e
      end

      if block
        begin
          yield(self)
        ensure
          cleanup_upload
        end
      end
    end

    # Cleans up cache of shared files uploaded to all nodes. This cache is created by the {prepare_upload} method.
    def self.cleanup_upload
      [
        TMP_TARBALL,
        TMP_SOLO_RB,
        TMP_CHEF_SOLO_APPLY
      ].each do |path|
        path.unlink if path.exist?
      end
    end

   # Uploads configuration information to node.
   #
   # IMPORTANT: You must first call {prepare_upload} to create the shared files that will be uploaded.
   def upload
     if @sudo != nil and @sudo != ""
       upload_sudo
     else   
       self.say("*** Uploading configuration ***")
 
       self.say("*** Removing old files *** ", false)
	   self.execute("#{@sudo}rm -rf \"#{ETC_CHEF}\" \"#{VAR_POCKETKNIFE}\" \"#{VAR_POCKETKNIFE_CACHE}\" \"#{CHEF_SOLO_APPLY}\" \"#{CHEF_SOLO_APPLY_ALIAS}\"")
       self.execute <<-HERE
  rm -f #{@log_location}/apply.log &&
  umask 0377 &&
    mkdir -p "#{ETC_CHEF}" "#{VAR_POCKETKNIFE}" "#{VAR_POCKETKNIFE_CACHE}" "#{CHEF_SOLO_APPLY.dirname}" 
   HERE
 
       self.say("Uploading new files...", false)
       self.say("Uploading #{self.local_node_json_pathname} to #{NODE_JSON}", false)
       self.connection.file_upload(self.local_node_json_pathname.to_s, NODE_JSON.to_s)
       self.connection.file_upload(TMP_TARBALL.to_s, VAR_POCKETKNIFE_TARBALL.to_s)
       self.say("Installing new files...", false)
       self.execute <<-HERE, true
   cd "#{VAR_POCKETKNIFE_CACHE}" &&
   tar xvf "#{VAR_POCKETKNIFE_TARBALL}" &&
   chmod -R u+rwX,go= . &&
   chown -R root:root . &&
   mv "#{TMP_SOLO_RB}" "#{SOLO_RB}" &&
   mv "#{TMP_CHEF_SOLO_APPLY}" "#{CHEF_SOLO_APPLY}" &&
   chmod u+x "#{CHEF_SOLO_APPLY}" &&
   ln -s "#{CHEF_SOLO_APPLY.basename}" "#{CHEF_SOLO_APPLY_ALIAS}" &&
   rm "#{VAR_POCKETKNIFE_TARBALL}" &&
   mv * "#{VAR_POCKETKNIFE}"
       HERE
 
       self.say("*** Finished uploading! *** ", false)
    end
 end   

    # Uploads configuration information to node.
    #
    # IMPORTANT: You must first call {prepare_upload} to create the shared files that will be uploaded.
    def upload_sudo
      self.say("****************************************** ")
      self.say("*** Uploading configuration using sudo *** ")
      self.say("****************************************** ")
      self.say("*** Removing old files ***", false)
	  self.execute("#{@sudo}rm -rf \"#{ETC_CHEF}\" \"#{VAR_POCKETKNIFE}\" \"#{VAR_POCKETKNIFE_CACHE}\" \"#{CHEF_SOLO_APPLY}\" \"#{CHEF_SOLO_APPLY_ALIAS}\"")
      self.execute <<-HERE
  #{@sudo}rm -f #{@log_location}/apply.log &&
   umask 0377 &&
  #{@sudo}mkdir -p "#{ETC_CHEF}" "#{VAR_POCKETKNIFE}" "#{VAR_POCKETKNIFE_CACHE}" "#{CHEF_SOLO_APPLY.dirname}" &&
  #{@sudo}chmod -R a+rwX "#{ETC_CHEF}" &&
  #{@sudo}chmod -R a+rwX "#{VAR_POCKETKNIFE}" &&
  #{@sudo}chmod -R a+rwX "#{VAR_POCKETKNIFE_CACHE}"
  HERE

      self.say("*** Uploading new files ***", false)
      self.say("Uploading #{self.local_node_json_pathname} to #{NODE_JSON}", false)
      self.connection.file_upload(self.local_node_json_pathname.to_s, NODE_JSON.to_s)
      self.connection.file_upload(TMP_TARBALL.to_s, VAR_POCKETKNIFE_TARBALL.to_s)
      self.say("*** Installing new files ***", false)
      self.execute <<-HERE, true
  cd "#{VAR_POCKETKNIFE_CACHE}" &&
  #{@sudo}tar xvf "#{VAR_POCKETKNIFE_TARBALL}" &&
  #{@sudo}chmod -R a+rwX "#{VAR_POCKETKNIFE_CACHE}"  &&
  #{@sudo}mv "#{TMP_SOLO_RB}" "#{SOLO_RB}" &&
  #{@sudo}mv "#{TMP_CHEF_SOLO_APPLY}" "#{CHEF_SOLO_APPLY}" &&
  #{@sudo}chmod u+x "#{CHEF_SOLO_APPLY}" &&
  #{@sudo}ln -s "#{CHEF_SOLO_APPLY.basename}" "#{CHEF_SOLO_APPLY_ALIAS}" &&
  #{@sudo}rm "#{VAR_POCKETKNIFE_TARBALL}" &&
  #{@sudo}mv * "#{VAR_POCKETKNIFE}"
      HERE
      self.say("*************************** ", false)
      self.say("*** Finished uploading! *** ", false)
      self.say("*************************** ", false)
    end
    
   # rspec test the configuration module on the node.
    def foodcritic 
	     self.install
         unless self.has_executable?("foodcritic")
          self.install_foodcritic
         end    
         self.say("******************* ", true)
         self.say("*** foodcritic  *** ", true)
         self.say("******************* ", true)
	     self.say("***sudo is #{@sudo} ", true)	  	  
         begin 
	     self.execute(<<-HERE, true)
   #{@sudo} foodcritic #{@foodcritic}  > #{@log_location}/foodcritic.log
	 HERE
         rescue
         end 
         self.say("*** showing last 40 lines from #{@log_location}/foodcritic.log *** ")
         self.execute("#{@sudo} tail -n 40 #{@log_location}/foodcritic.log", true)		 
		 self.say("*** Finished foodcritic full log is at #{@log_location}/foodcritic.log ***")
     end  
	 
	 
   # rspec test the configuration module on the node.
    def rspec_test 
	     self.install
         unless self.has_executable?("rspec")
          self.install_chefspec
         end 
         self.berks_run		 
         self.say("******************************************************************* ", true)
         self.say("*** RSpec testing module #{@rspec} *** ", true)
         self.say("******************************************************************* ", true)
	     self.say("***sudo is #{@sudo} ", true)	  	  
         begin 
		 # cd #{@rspec} &&		
	     self.execute(<<-HERE, true)
	cd #{VAR_POCKETKNIFE} &&	 
    #{@sudo} rspec #{@rspec} > #{@log_location}/rspec.log
	 HERE
         rescue
         end 
         self.say("*** showing last 40 lines from #{@log_location}/rspec.log *** ")
         self.execute("#{@sudo} tail -n 40 #{@log_location}/rspec.log", true)		 
		 self.say("*** Finished Rspec testing full log is at #{@log_location}/rspec.log ***")
     end  
	 
	 def berks_run 
	  if self.connection.file_exists?("#{VAR_POCKETKNIFE_BERKSFILE}")
       self.say("************************************************************************** ", true)
       self.say("*** Run berks install using Berksfile to install in cookbooks repo dir *** ", true)
       self.say("************************************************************************** ", true)	  
	   begin 
	    command = "#{@sudo} berks install --path=cookbooks "
        command << " -d" if self.pocketknife.verbosity == true
	    self.execute(<<-HERE, true)
       cd #{VAR_POCKETKNIFE} &&
       #{command}
       HERE
        rescue
         error_run = true 
        end
	   end	
	  end
    

    # Applies the configuration to the node. Installs Chef, Ruby and Rubygems if needed.
    def apply
      self.install
      self.berks_run	
      self.say("****************************** ", true)
      self.say("*** Applying configuration *** ", true)
      self.say("****************************** ", true)
      command = "#{@sudo}chef-solo -j #{NODE_JSON} #{@xoptions}"
      command << " -l debug" if self.pocketknife.verbosity == true
	  command << " --why-run" if self.pocketknife.why_run == true
      self.execute(command, true)
	  self.execute("#{@sudo}rm -rf \"#{ETC_CHEF}\" \"#{VAR_POCKETKNIFE}\" \"#{VAR_POCKETKNIFE_CACHE}\" \"#{CHEF_SOLO_APPLY}\" \"#{CHEF_SOLO_APPLY_ALIAS}\"") if @deleterepo == true
      self.say("*** Finished applying! *** ")
    end

    # Deploys the configuration to the node, which calls {#upload} and {#apply}.
    def deploy
      self.upload
	  self.foodcritic_run if @foodcritic != nil and @foodcritic != ""
	  self.rspec_test if @rspec != nil and @rspec != "" 	  
      self.apply
    end

    # Executes commands on the external node.
    #
    # @param [String] commands Shell commands to execute.
    # @param [Boolean] immediate Display execution information immediately to STDOUT, rather than returning it as an object when done.
    # @return [Rye::Rap] A result object describing the completed execution.
    # @raise [ExecutionError] Raised if something goes wrong with execution.
    def execute(commands, immediate=false)
      self.say("Executing:\n#{commands}", false)
      if immediate
        self.connection.stdout_hook {|line| puts line}
      end
      return self.connection.execute("(#{commands}) 2>&1")
    rescue Rye::Err => e
      raise Pocketknife::ExecutionError.new(self.name, commands, e, immediate)
    ensure
      self.connection.stdout_hook = nil
    end

    # Remote path to Chef's settings
    # @private
    ETC_CHEF = Pathname.new("/etc/chef")
    # Remote path to solo.rb
    # @private
    SOLO_RB = ETC_CHEF + "solo.rb"
    # Remote path to node.json
    # @private
    NODE_JSON = ETC_CHEF + "node.json"
    # Remote path to pocketknife's deployed configuration
    # @private
    VAR_POCKETKNIFE = Pathname.new("/var/local/pocketknife")
    # Remote path to pocketknife's cache
    # @private
    VAR_POCKETKNIFE_CACHE = VAR_POCKETKNIFE + "cache"
    # Remote path to temporary tarball containing uploaded files.
    # @private
    VAR_POCKETKNIFE_TARBALL = VAR_POCKETKNIFE_CACHE + "pocketknife.tmp"
    # Remote path to pocketknife's cookbooks
    # @private
    VAR_POCKETKNIFE_COOKBOOKS = VAR_POCKETKNIFE + "cookbooks"
    # Remote path to pocketknife's site-cookbooks
    # @private
    VAR_POCKETKNIFE_SITE_COOKBOOKS = VAR_POCKETKNIFE + "site-cookbooks"
    # Remote path to pocketknife's roles
    # @private
    VAR_POCKETKNIFE_ROLES = VAR_POCKETKNIFE + "roles"
    # Remote path to pocketknife's roles
    # @private
    VAR_POCKETKNIFE_DATA_BAGS = VAR_POCKETKNIFE + "data_bags"
	# Remote path to pocketknife's cookbooks
    # @private
    VAR_POCKETKNIFE_BERKSFILE = VAR_POCKETKNIFE + "Berksfile"
    # Content of the solo.rb file
    # @private
    SOLO_RB_CONTENT = <<-HERE
file_cache_path "#{VAR_POCKETKNIFE_CACHE}"
cookbook_path ["#{VAR_POCKETKNIFE_COOKBOOKS}", "#{VAR_POCKETKNIFE_SITE_COOKBOOKS}"]
role_path "#{VAR_POCKETKNIFE_ROLES}"
data_bag_path "#{VAR_POCKETKNIFE_DATA_BAGS}"
    HERE
    # Remote path to chef-solo-apply
    # @private
    CHEF_SOLO_APPLY = Pathname.new("/usr/local/sbin/chef-solo-apply")
    # Remote path to csa
    # @private
    CHEF_SOLO_APPLY_ALIAS = CHEF_SOLO_APPLY.dirname + "csa"
    # Content of the chef-solo-apply file
    # @private
    CHEF_SOLO_APPLY_CONTENT = <<-HERE
#!/bin/sh
chef-solo -j #{NODE_JSON} "$@"
    HERE
    # Local path to solo.rb that will be included in the tarball
    # @private
    TMP_SOLO_RB = Pathname.new("solo.rb.tmp")
    # Local path to chef-solo-apply.rb that will be included in the tarball
    # @private
    TMP_CHEF_SOLO_APPLY = Pathname.new("chef-solo-apply.tmp")
    # Local path to the tarball to upload to the remote node containing shared files
    # @private
    TMP_TARBALL = Pathname.new("pocketknife.tmp")
  end
 end

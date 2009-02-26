namespace :audit do
  desc "send the audit feed generator to a remote server"
  task :deploy do
    hostname = Capistrano::CLI.ui.ask("audit install hostname: ")
    username = Capistrano::CLI.ui.ask("audit install username: ")
    password = Capistrano::CLI.password_prompt("audit install password: ")
    password = nil if password.empty?
    Net::SFTP.start(hostname, username, :auth_methods => ['publickey', 'password'], :password => password) do |sftp|
      sftp.mkdir!("backup-toolkit-audit") unless sftp.dir.entries('.').map(&:name).include? 'backup-toolkit-audit'
      sftp.mkdir!("backup-toolkit-audit/audit") unless sftp.dir.entries('backup-toolkit-audit').map(&:name).include? 'audit'
      sftp.mkdir!("backup-toolkit-audit/config") unless sftp.dir.entries('backup-toolkit-audit').map(&:name).include? 'config'
      sftp.mkdir!("backup-toolkit-audit/lib") unless sftp.dir.entries('backup-toolkit-audit').map(&:name).include? 'lib'
      
      sftp.upload!("audit/generate_feeds.rb", "backup-toolkit-audit/audit/generate_feeds.rb")
      sftp.upload!("config/config-repo.yml", "backup-toolkit-audit/config/config-repo.yml")
      sftp.upload!("lib/confighandler.rb", "backup-toolkit-audit/lib/confighandler.rb")
    end
  end
end


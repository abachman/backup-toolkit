# In the interest of backup.dreamhost.com compatibility, all :roles => :backup tasks 
# should rely exclusively on sftp and scp.

namespace :backup do
  desc "list backup files on the backup server"
  task :list, :roles => :backup do
    Net::SFTP.start(backup_server['hostname'], backup_server['username'], 
                    :password => backup_server['password'], :auth_methods => %w(publickey password)) do |sftp|
      if (sftp.dir.entries(".").map { |e| e.name }).include? backup_server['backup_storage']
        puts (sftp.dir.entries(backup_server['backup_storage']).map { |e| e.name }).sort
      else 
        puts "Backup storage directory, '#{ backup_server['backup_storage'] }', doesn't exist on #{ backup_server['ssh_address'] }"
      end
    end
  end

  task :rootdir, :roles => :backup do
    # List root dir of backup host.
    Net::SFTP.start(backup_server['hostname'], backup_server['username'], 
                    :password => backup_server['password'], :auth_methods => %w(publickey password)) do |sftp|
      entries = (sftp.dir.entries(".").map { |e| e.name })
      puts entries.inspect      
    end
  end

#  NEEDS TO RELY ON SFTP
#  desc "dump a given backup package"
#  task :dump, :roles => :backup do 
#    if ENV['BACKUP_FILE'] 
#      fname = "#{ backup_server['backup_storage'] }/#{ ENV['BACKUP_FILE'] }"
#      if /\.tar\.gz/ =~ fname
#        run "[ -r #{ fname } ] && tar tf #{ fname } || echo 'error opening file'"
#      elsif /\.sql\.gz/ =~ fname
#        run "[ -r #{ fname } ] && zcat #{ fname } || echo 'error opening file'"
#      else
#        run "echo \"unknown filetype, can't access\""
#      end
#    else
#      puts "No backup file specified. Run backup:list to get filenames and then run this"
#      puts "command again with the BACKUP_FILE=filename specified."
#    end
#  end
end


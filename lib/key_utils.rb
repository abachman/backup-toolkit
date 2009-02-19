# Key exchange utilities 
# 
# Create ssh keys on remote machines, add a key to a remote machine's
# .ssh/authorized_keys file, audit a remote machine's existing keys.

module SshKeyUtils
  class RemoteCredentials
    attr_accessor :address, :username, :password
  end
end


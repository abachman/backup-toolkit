# SLS Backup Toolkit 

backup-toolkit is a collection of Capistrano recipes and linux scripts intended to make the remote control of backups simple and painless. 

Goals: 

1. Simple
2. Painless

### Definititions

**administrator**

> Person doing adminisitration of backup-toolkit.

**admin**

> Machine from which administration occurs.

**node**

> The server on which backup-runner will execute. 

**backup** 

> Where all the backups are going to go.  It's really just a bucket.

**backup task** 

> A single, repeating backup, running on a node.

### Tell Me More

There are two halves to backup-toolkit, on the frontend, there's Capistrano making it easy to deploy, configure, run, and checkup on your servers. The frontend pieces are located in config and lib.

On the backend, there's the stuff in `dist/`.  When running `cap dist:install`, it all gets sent to your remote server (*node*) and is installed. **install.sh** has the scoop on what happens at the node during installation.

That's it, there aren't any scripts or pieces of the install that mess with your backup server.  As far as backup-toolkit is concerned, it's just a bit bucket.

Once the install has finished, running `cap backup:create` creates a new backup job that will execute sometime between 1 AM and 4 AM. (explicit scheduling is for the weak)

The backup-toolkit does the rest. In the interest of security and stability, we rely almost wholly on the standard linux toolkit.  All backups are scheduled with cron, created with tar or mysqldump, and transferred via ssh with public key authentication. 

### Requirements

You, the administrator, must have Ruby and Capistrano installed.  The nodes must have Ruby and ssh. Mysql and mysqldump is only necessary on nodes if they're going to be running mysql backup tasks. Beyond that it should run on any modern *nix distribution.

### Layout on Your Machine

    backup-toolkit/
      config/         # local server connections and settings files.
      lib/            # cap tasks to get stuff done.
      dist/           # what gets sent to a node to setup and run the
                        backups.
      test/           # a small handful of tests
      Capfile     
      Rakefile

### Setting Up Your Environment

Create config files in *backup-toolkit/config* on your machine manually or by using `cap connection:create`.  They look like: 

*config/sample-node.yml*

    # Example node configuration

    type: node
    id: ubuntu-general-VM
    hostname: 192.168.1.31
    username: adam

*config/sample-backup.yml*

    # Example backup configuration

    type: backup
    id: red5-VM-the-second
    hostname: 192.168.1.28
    username: red5server     
    backup_storage: backups   # where the backups will be stored relative to 
                              # username's home directory

*config/config-repo.yml*

    # Example connection repo config 

    type: connections
    id: central-connection-repository
    hostname: 192.168.1.31
    username: adam
    config_directory: connections

Create as many of either as you like, backup-toolkit will ask if it's not sure which configuration to use. Filename doesn't matter, but config files should all end with `.yml` or they won't be picked up. 

You will be prompted for a password every time backup-toolkit tries to load a configuration file, but if you've already done a key:sync on the server it's asking you about, you can leave the password blank.

If you're working in a team environment, and for the sake of easy auditing, you can set up a central configuration repository.  After searching your local ./config path, backup-toolkit will look in <code>username@hostname:~/path/to/configs</code> for node and backup config files.  **WARNING**: configurations in the remote repository with the same id as connections from your local directory will overwrite their local counterpart.

### Capistrano Tasks

    cap backup:list      # list backup files on the backup server
    cap dist:install     # install backup-toolkit on node
    cap dist:uninstall   # uninstall backup-toolkit on node
    cap keys:add         # send your key to a remote server (adhoc)
    cap keys:show:backup # show installed keys on backup
    cap keys:show:local  # show installed keys on your machine
    cap keys:show:node   # show installed keys on node
    cap keys:sync        # keys:sync:local keys:sync:remote
    cap keys:sync:local  # send your ssh key to node and backup
    cap keys:sync:remote # node's ssh key to backup
    cap node:create_task # Create new mysql or directory backup task
    cap node:execute     # force backup tasks on the selected node to run
    cap node:jobs        # list backup jobs on the node
    cap node:log         # dump node's run.log file (record of backups)

All tasks rely on the config files you created. If there's only one config file, backup-toolkit will use that by default. Otherwise it'll ask which one you want to use. 

Reminder: everytime backup-toolkit loads up a server config file, it prompts for a password. If you've already exchanged keys, it's safe to just leave it blank.

### Command Line Parameters

All tasks accept `BT_NODE=[node id]` and `BT_BACKUP=[backup id]` to skip the config selection prompt.  For example:

    cap keys:sync BT_NODE=ubuntu-general BT_BACKUP=red5-VM 

### Example Workflow

From admin:

1. `cap deploy` - follow the steps. Done.

Optional

`cap node:jobs` - show a listing of backup tasks on the node. The listing should be in Wikimedia format, suitable for documentation.

`cap node:log` - read the log file on a given node.

`cap backup:list` - show a listing of all archive files on a given backup server.

`cap keys:add` - add a key of your choice to the server of your choice. Takes optional `username` and `hostname` command line parameters.

### Coming Soon

* More backup auditing and reporting.  More attention paid to the backup server in general.
* Restore. 

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

On the backend, there's the stuff in *dist/*.  When running `cap dist:install`, it all gets sent to your remote server (*node*) and is installed. **install.sh** has the scoop on what happens at the node during installation.

That's it, there aren't any scripts or pieces of the install that mess with your backup server.  As far as backup-toolkit is concerned, it's just a bit bucket.

Once the install has finished, running `cap backup:create` creates a new backup job that will execute sometime between 1 AM and 4 AM. (explicit scheduling is for the weak)

The backup-toolkit does the rest. In the interest of security and stability, we rely almost wholly on the standard linux toolkit.  All backups are scheduled with cron, created with tar or mysqldump, and transferred via ssh with public key authentication. 

### Requirements

You, the administrator, must have Ruby and Capistrano installed.  The nodes must have Ruby and ssh. Mysql and mysqldump is only necessary if you're creating mysql backup tasks. Beyond that it should run on any modern linux distribution.

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

Create config files in *backup-toolkit/config* on your machine.  They look like: 

*config/sample-node.yml*

    # Example node configuration

    type: node
    id: ubuntu-general-VM
    hostname: 192.168.1.31
    username: adam
    password: adam

or 

*config/sample-backup.yml*

    # Example backup configuration

    type: backup
    id: red5-VM-the-second
    hostname: 192.168.1.28
    username: red5server
    password: red5server
    backup_storage: /home/red5server/backups

The differences to notice are the `type` fields and the `backup_storage` field in the backup config file.  Create as many of either as you like, backup-toolkit will ask if it's not sure which configuration to use. Filename doesn't matter, but config files should all end with `.yml` or they won't be picked up.

### Capistrano Tasks

    cap apply_key:all  # (0) send your ssh key to node and backup and send 
                         node key to backup.
    cap backup:create  # (2) Create new mysql or directory backup task
    cap backup:execute # force backup tasks on node to run
    cap backup:jobs    # list backup jobs on node
    cap backup:list    # list backup files stored on backup
    cap dist:install   # (1) install backup-toolkit on a node
    cap dist:uninstall # uninstall backup-toolkit on a node

All tasks rely on the config files you created.  If there's only one config file, backup-toolkit will use that by default.  Otherwise it'll ask which one you want to use.

### Example Workflow

From admin:

1. Create configs for backup and production.

2. `cap apply_key:all` - make sure backup knows who node is and node knows who backup is. Also, make sure both know the admin. Some folks like backup-toolkit for this feature alone. (see *lib/key_exchange.rb* for details)

3. `cap dist:install` - this one is safe to repeat if the software is updated.  It's recommended, in fact, if you've created backup jobs on the node.  dist:uninstall will wipe out all your backup tasks, dist:install will simply overwrite the scripts and master config file.

4. `cap backup:create` - repeat as neccessary.

5. `cap backup:execute` - just to make sure everything runs smoothly.

### Coming Soon

* Command line flags to set preferred servers.
* More backup auditing and reporting.  More attention paid to the backup server in general.
* Restore. 

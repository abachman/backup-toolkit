# SLS Backup Toolkit 

### Definititions

**production**

> The server on which backup-runner will execute. There 

**backup** 

> Where all the backups are going to go.  It's really just a bucket.

### Layout on your machine

    backup-toolkit/
      config/         # local server connections and settings files.
      lib/            # cap tasks to get stuff done.
      dist/           # what gets sent to production to run the backups.
      test/           # a small handful of tests
      Capfile     
      Rakefile

### Suggested workflow

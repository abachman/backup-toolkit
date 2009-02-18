require 'rubygems'
require 'test/unit'
require 'fileutils'

LOCAL_PATH = File.dirname(__FILE__)

class TarDumpTest < Test::Unit::TestCase 
  def setup
    @ltmp = File.join(LOCAL_PATH, "tmp")
    FileUtils.mkdir(@ltmp)
    @command = File.join(LOCAL_PATH, '..', 'tar-dump.sh')
    @output = File.join(@ltmp, "tar-dump.out")
    @tfile = 'test'
    create_simple_dir
  end
  def teardown
    @out = nil
    @tarlist = nil
    FileUtils.rm_rf(@ltmp) # WARNING: rm -rf in use. Please use caution.
  end

  def test_help_displays_usage
    `#{@command} -h 2> #{@output}`
    assert_match(/Usage: tar-dump.sh: /, out)
  end

  def test_verbose_displays_output_path
    `#{@command} -v -ftest -d/tmp #{@sdir} > #{@output}`
    assert_match(/[0-9]*-test\.tar\.gz$/, out)
  end
#
  def test_creates_tar_gz_file
    # exec 
    `#{@command} -v -ftest -d#{@ltmp} #{@sdir} > #{@output}`
    fname = /([0-9_-]*-test\.tar\.gz)$/.match(out)[0]
    assert File.exist?(File.join(@ltmp, fname)), "Tar file should exist"
  end

  def test_excludes_git_with_c_arg
    # exec 
    `#{@command} -v -f#{@tfile} -c -d#{@ltmp} #{@sdir} > #{@output}`
    assert_no_match(/\.git/, out, ".git dir shouldn't exist in verbose output")
    @fname = /([0-9_-]*-#{@tfile}\.tar\.gz)$/.match(out)[0]
    assert File.exist?(File.join(@ltmp, @fname)), ".tar.gz file should exist"
    assert_no_match(/\.git/, tarlist, ".git dir shouldn't be in tar file")
  end

  def test_excludes_log_files_with_e_arg
    `#{@command} -v -f#{@tfile} -c -e*.log -d#{@ltmp} #{@sdir} > #{@output}`
    assert_no_match(/.*\.log$/, out, "log files shouldn't exist in verbose output")
    @fname = /([0-9_-]*-#{@tfile}\.tar\.gz)$/.match(out)[0]
    assert File.exist?(File.join(@ltmp, @fname)), ".tar.gz file should exist"
    assert_no_match(/.*\.log$/, tarlist, "log files shouldn't be in tar file")
  end

  def test_excludes_multiple_file_types_with_e_arg
    `#{@command} -v -f#{@tfile} -c -e*.log -e*.txt -d#{@ltmp} #{@sdir} > #{@output}`
    assert_no_match(/.*\.log$/, out, "log files shouldn't exist in verbose output")
    assert_no_match(/.*\.txt$/, out, "txt files shouldn't exist in verbose output")
    @fname = /([0-9_-]*-#{@tfile}\.tar\.gz)$/.match(out)[0]
    assert File.exist?(File.join(@ltmp, @fname)), ".tar.gz file should exist"
    assert_no_match(/.*\.log$/, tarlist, "log files shouldn't be in tar file")
    assert_no_match(/.*\.txt$/, tarlist, "txt files shouldn't be in tar file")
  end

  private 
    def create_simple_dir 
      # test/
      #   file1.txt
      #   file2.rb
      #   log/
      #     log1.log
      #     log2.log
      #   .git/
      #     gitfile
      #   .svn/
      #     svnfile
      d = File.join(@ltmp, 'test')  
      FileUtils.mkdir_p(d)
      FileUtils.touch File.join(d, 'file1.txt')
      FileUtils.touch File.join(d, 'file2.txt')

      FileUtils.mkdir_p(File.join(d, 'log'))
      FileUtils.touch File.join(d, 'log', 'file1.log')
      FileUtils.touch File.join(d, 'log', 'file2.log')

      FileUtils.mkdir_p(File.join(d, '.git'))
      FileUtils.touch File.join(d, '.git', 'file1.git')
      
      FileUtils.mkdir_p(File.join(d, '.svn'))
      FileUtils.touch File.join(d, '.svn', 'file1.svn')
      @sdir = d
    end

    def tarlist
      @tarlist ||= `tar tf #{File.join(@ltmp, @fname)}`
    end

    def cleanup f
      FileUtils.rm_f f
    end

    def out
     @out ||= File.new(@output).read
    end
end

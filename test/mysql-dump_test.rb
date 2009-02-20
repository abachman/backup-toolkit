require 'rubygems'
require 'test/unit'
require 'fileutils'

class MysqlDumpTest < Test::Unit::TestCase 
  def setup
    @command = File.join(File.dirname(__FILE__), '..', 'dist', 'mysql-dump.sh')
    @output = "/tmp/mysql-dump.out" 
  end

  def teardown
    cleanup @output
    @out = nil
  end

  def test_help_displays_usage
    `#{@command} -h 2> #{@output}`
    assert_match(/Usage: mysql-dump.sh /, out)
  end

  def test_lists_databases
    `#{@command} -l -psecret > #{@output}`
    assert_match(/^information_schema$/, out)
  end

  def test_creates_backup
    `#{@command} -psecret -t/tmp -ftestfilename -v > #{@output}`
    assert_match(/[0-9_-]*-testfilename\.sql\.gz$/, out, 'should match filename')
    fname = /([0-9_-]*-testfilename\.sql\.gz)$/.match(out)[0]
    assert File.exist?("/tmp/#{fname}")
    cleanup fname
  end

  private 
    def cleanup f
      FileUtils.rm_f f
    end
    def out
     @out ||= File.new(@output).read
    end
end

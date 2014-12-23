#!/usr/bin/ruby
#
# This scipt is designed to work with mock 1.2.0+

require 'uri'
require 'shellwords'

class Mock
  attr_reader :root

  def initialize(options = {})
    @root = options[:root]
  end

  def home
    @home ||= chroot("cd ~ && pwd", :quiet => true).strip
  end

  def install(*cmd)
    command("--install", cmd)
  end

  def downgrade(*cmd)
    command("--pm-cmd downgrade", cmd)
  end

  def chroot(*cmd)
    command("--chroot", cmd)
  end

  def copyout(*cmd)
    command("--copyout", cmd)
  end

  def command(*cmd)
    cmd.last.flatten!
    cmd.last.map! {|c| (c.kind_of?(String) && c =~ /[ ~*]/) ? "'#{c}'" : c}
    options = cmd.flatten!.last.kind_of?(Hash) ? cmd.pop : {}

    mock_command = %w(mock)
    mock_command += ['-r', root] if root
    mock_command += %w(-q) if options[:quiet]
    mock_command += cmd

    p mock_command.compact.join ' ' if ENV['DEBUG']
    `#{mock_command.compact.join ' '}`
  end
end

mock = Mock.new :root => 'ruby'

mock.install %w(autoconf bison ruby subversion)

SVNURL = URI.parse("http://svn.ruby-lang.org/repos/ruby/")
mock.chroot "svn checkout #{SVNURL}trunk ~/ruby"
mock.chroot "cd ~/ruby && tool/make-snapshot tmp"

ruby_archives = mock.chroot "ls ~/ruby/tmp | grep bz2", :quiet => true
ruby_archive = ruby_archives.split.sort.last

mock.copyout "~/ruby/tmp/#{ruby_archive}", "."

ruby_revision = ruby_archive[/-r(\d+).tar.bz2/, 1]

ruby_spec = File.read('ruby.spec')

# Fix Ruby revision.
ruby_revision_old = ruby_spec[/%global revision (\d{5})/, 1]
ruby_spec.gsub!(/#{ruby_revision_old}/, ruby_revision)

File.open('ruby.spec', "w") {|file| file.puts ruby_spec }


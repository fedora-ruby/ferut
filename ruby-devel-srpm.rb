#!/usr/bin/ruby
#
# This scipt is designed to work with mock 1.2.0+

require 'date'
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
    command("--unpriv --chroot", cmd)
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
    mock_command += %w(--enable-network)
    mock_command += cmd

    p mock_command.compact.join ' ' if ENV['DEBUG']
    `#{mock_command.compact.join ' '}`
  end
end

mock = Mock.new :root => 'ruby'

mock.install %w(make autoconf ruby rubygems rubygem-json git)

GITURL = URI.parse("https://github.com/ruby/ruby")
mock.chroot "git clone #{GITURL} ~/ruby"
make_snapshot_log = mock.chroot "cd ~/ruby && tool/make-snapshot -packages=xz -keep_temp tmp #{ENV['VERSION']}"

revision_match = make_snapshot_log.lines[0].match /@(.*)$/
if !revision_match || (ruby_revision = revision_match[1].strip[0, 10]).empty?
  raise <<~HEREDOC
    make-snapshot output format different then expected. Revision hasn't been detected.

    ~~~
    #{make_snapshot_log}
    ~~~
  HEREDOC
end

ruby_archives = mock.chroot "ls ~/ruby/tmp | grep xz", :quiet => true
ruby_archive = ruby_archives.split.find {|ra| ra =~ /#{ruby_revision}/} || ruby_archives.split.find {|ra| ra =~ /#{ENV['VERSION']}/}

mock.copyout "~/ruby/tmp/#{ruby_archive}", "."

snapshot_directory = make_snapshot_log.lines[1][/'(.*)'/, 1]
if snapshot_directory.empty?
  raise <<~HEREDOC
    make-snapshot output format different then expected. Snapshot directory hasn't been detected.

    ~~~
    #{make_snapshot_log}
    ~~~
  HEREDOC
end
snapshot_directory = mock.chroot "find #{File.dirname snapshot_directory} -mindepth 1 -maxdepth 1 | head -1"
snapshot_directory.strip!

default_gems = mock.chroot "cd #{snapshot_directory}" + %q[ && find {lib,ext} -name *.gemspec -exec ruby -Ilib:ext -e "Gem::Specification.load(%({})).tap {|s| puts %(\"#{s.name}\" => \"#{s.version}\",)}" \; 2> /dev/null]
puts default_gems.lines.sort.join if ENV['DEBUG']
default_gems = "{#{default_gems}}"
default_gems = eval(default_gems)

bundled_gems = mock.chroot %Q[cd #{snapshot_directory} && cat gems/bundled_gems]
puts bundled_gems if ENV['DEBUG']
bundled_gems.gsub!(/\shttp.*/, '')
bundled_gems = bundled_gems.lines.delete_if {|l| l.strip.empty? || l.start_with?(?#)}
bundled_gems = bundled_gems.map {|l| l.split}
bundled_gems = bundled_gems.to_h

# Cleanup snapshot temporary directory. All data has been mined at this stage.
mock.chroot %Q[rm -rf #{File.dirname snapshot_directory}]

ruby_spec = File.read('ruby.spec')

# Fix Ruby revision.
ruby_revision_old = ruby_spec[/%global revision (.*)$/, 1]
ruby_spec.gsub!(/#{ruby_revision_old}/, ruby_revision)

# Update changelog date. This date is used by RPM as a source for
# SOURCE_DATE_EPOCH, influencing the date in NVR.
current_date = Date.today.strftime("%a %b %d %Y")
ruby_spec.sub!(/(%changelog\n?\*) (\w{3} \w{3} \d{2} \d{4})/, "\\1 #{current_date}")

# Fix gem versions.
remaining_gems = default_gems.merge(bundled_gems).reject do |name, version|
  reject = false

  underscore_name = name.gsub(?-, ?_)
  ruby_spec.gsub!(/ #{underscore_name}_version \d.*/) do |match|
    reject = true
    " #{underscore_name}_version #{version}"
  end

  reject
end

unless remaining_gems.empty?
  puts "!!! The following gems should possibly be added into ruby.spec file:"
  remaining_gems.sort.each {|name, version| puts "#{name} - #{version}"}
end

File.open('ruby.spec', "w") {|file| file.puts ruby_spec }


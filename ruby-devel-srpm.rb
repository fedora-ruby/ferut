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

mock.install %w(autoconf bison ruby rubypick rubygems rubygem-json git)

GITURL = URI.parse("https://github.com/ruby/ruby")
mock.chroot "git clone #{GITURL} ~/ruby"
make_snapshot_log = mock.chroot "cd ~/ruby && tool/make-snapshot -packages=xz tmp #{ENV['VERSION']}"

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
ruby_archive = ruby_archives.split.find {|ra| ra =~ /#{ruby_revision}/}

mock.copyout "~/ruby/tmp/#{ruby_archive}", "."

default_gems = mock.chroot %q[cd ~/ruby && find {lib,ext} -name *.gemspec -exec ruby -Ilib:ext -e "Gem::Specification.load(%({})).tap {|s| puts %(\"#{s.name}\" => \"#{s.version}\",)}" \;]
puts default_gems.lines.sort.join if ENV['DEBUG']
default_gems = "{#{default_gems}}"
default_gems = eval(default_gems)

bundled_gems = mock.chroot 'cd ~/ruby && cat gems/bundled_gems'
puts bundled_gems if ENV['DEBUG']
bundled_gems.gsub!(/\shttp.*/, '')
bundled_gems = bundled_gems.lines.map {|l| l.split}
bundled_gems = bundled_gems.to_h

ruby_spec = File.read('ruby.spec')

# Fix Ruby revision.
ruby_revision_old = ruby_spec[/%global revision (.*)$/, 1]
ruby_spec.gsub!(/#{ruby_revision_old}/, ruby_revision)

# Fix gem versions.
remaining_gems = default_gems.merge(bundled_gems).reject do |name, version|
  reject = false

  ruby_spec.gsub!(/\/#{name}-\d.*\.gemspec/) do |match|
    reject = true
    match !~ /%\{/ ? "/#{name}-#{version}.gemspec" : match
  end

  underscore_name = name.gsub(?-, ?_)
  ruby_spec.gsub!(/ #{underscore_name}_version \d.*/) do |match|
    reject = true
    " #{underscore_name}_version #{version}"
  end

  reject
end

unless remaining_gems.empty?
  puts "!!! Following gems were not found in ruby.spec file:"
  remaining_gems.each {|name, version| puts "#{name} - #{version}"}
end

File.open('ruby.spec', "w") {|file| file.puts ruby_spec }


# encoding: utf-8
#--
#   Copyright (C) 2011-2014 Gitorious AS
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
require "gitorious/configurable"
require "gitorious/mount_point"
require "gitorious/openid"
require "gitorious/kerberos"

module Gitorious
  VERSION = "3.2.1"

  # Application-wide configuration settings.
  Configuration = Configurable.new("GITORIOUS")
  Configuration.rename("gitorious_host", "host")
  Configuration.rename("sender_email_address", "email_sender")
  Configuration.rename("gitorious_support_email", "support_email")
  Configuration.rename("gitorious_clone_host", "git_daemon_host")
  Configuration.rename("use_ssl", "scheme", <<-EOF) { |use_ssl| use_ssl ? "https" : "http" }
The scheme setting should be set to "http"
or "https".
  EOF
  Configuration.rename("gitorious_user", "user")
  Configuration.rename("repos_and_projects_private_by_default", "projects_default_private", <<-EOF)
Please note that this setting has been
split into two settings:
projects_default_private and repositories_default_private.
  EOF
  Configuration.rename("disable_record_throttling", "enable_record_throttling", <<-EOF) { |d| !d }
You should invert this value.
  EOF
  Configuration.rename("exception_notification_emails", "exception_recipients")
  Configuration.rename("only_site_admins_can_create_projects", "enable_project_approvals")
  Configuration.rename("hide_http_clone_urls", "enable_git_http", <<-MSG) { |d| !d }
You should invert this value.
  MSG
  Configuration.rename("hide_git_clone_urls", "enable_git_daemon", <<-MSG) { |d| !d }
You should invert this value.
  MSG
  Configuration.rename("custom_username_label", "username_label")
  Configuration.rename("use_ldap_authorization", "enable_ldap_authorization")
  Configuration.rename("show_license_descriptions_in_sidebar", "enable_sidebar_license_descriptions")

  Configuration.on_deprecation do |old, new, comment|
    $stderr.puts(<<-EOF)
WARNING! Setting '#{old}' in config/gitorious.yml is deprecated.
Use '#{new}' instead. Many configuration settings have changed
in Gitorious 3, please refer to config/gitorious.sample.yml for full documentation.
#{comment}
    EOF
  end

  def self.site
    return @site if @site && cache?
    host = Gitorious::Configuration.get("host", "gitorious.local")
    port = Gitorious::Configuration.get("port")
    scheme = Gitorious::Configuration.get("scheme")
    @site = Gitorious::HttpMountPoint.new(host, port, scheme)
  end

  def self.scheme; site.scheme; end
  def self.host; site.host; end
  def self.port; site.port; end
  def self.ssl?; site.ssl?; end
  def self.default_port?; site.default_port?; end
  def self.url(path); site.url(path); end

  def self.git_daemon
    return @git_daemon if @git_daemon && cache?
    return nil if !Gitorious::Configuration.get("enable_git_daemon", false)
    host = Gitorious::Configuration.get("git_daemon_host") { Gitorious.host }
    port = Gitorious::Configuration.get("git_daemon_port")
    @git_daemon = Gitorious::GitMountPoint.new(host, port)
  end

  def self.ssh_daemon
    return @ssh_daemon if @ssh_daemon && cache?
    return nil if !Gitorious::Configuration.get("enable_ssh_daemon", true)
    host = Gitorious::Configuration.get("ssh_daemon_host") { Gitorious.host }
    port = Gitorious::Configuration.get("ssh_daemon_port") { 22 }
    @ssh_daemon = Gitorious::GitSshMountPoint.new(Gitorious.user, host, port)
  end

  def self.git_http
    return @git_http if @git_http && cache?
    return nil if !Gitorious::Configuration.get("enable_git_http", true)
    host = Gitorious::Configuration.get("git_http_host") { Gitorious.host }
    port = Gitorious::Configuration.get("git_http_port") { Gitorious.port }
    scheme = Gitorious::Configuration.get("git_http_scheme") { Gitorious.scheme }
    @git_http = Gitorious::HttpMountPoint.new(host, port, scheme)
  end

  def self.default_remote_url(repository)
    (ssh_daemon || git_daemon || git_http).url(repository.gitdir)
  end

  def self.email_sender
    return @email_sender if @email_sender && cache?
    default = "Gitorious <no-reply@#{host}>"
    @email_sender = Gitorious::Configuration.get("email_sender", default)
  end

  def self.user
    return @user if @user && cache?
    @user = Gitorious::Configuration.get("user", "git")
  end

  def self.public?
    return @public if !@public.nil? && cache?
    @public = Gitorious::Configuration.get("public_mode", true)
  end

  def self.private_repositories?
    return @private_repos if !@private_repos.nil? && cache?
    @private_repos = Gitorious::Configuration.get("enable_private_repositories", false)
  end

  def self.projects_default_private?
    return @projdefpriv if !@projdefpriv.nil? && cache?
    @projdefpriv = private_repositories? && Gitorious::Configuration.get("projects_default_private", false)
  end

  def self.repositories_default_private?
    return @repodefpriv if !@repodefpriv.nil? && cache?
    @repodefpriv = private_repositories? && Gitorious::Configuration.get("repositories_default_private", false)
  end

  def self.support_email
    return @support_email if @support_email && cache?
    @support_email = Gitorious::Configuration.get("support_email") do
      "gitorious-support@#{host}"
    end
  end

  def self.archive_cache_dir
    return @archive_cache_dir if @archive_cache_dir && cache?
    @archive_cache_dir = Gitorious::Configuration.get("archive_cache_dir")
  end

  def self.archive_work_dir
    return @archive_work_dir if @archive_work_dir && cache?
    @archive_work_dir = Gitorious::Configuration.get("archive_work_dir")
  end

  def self.diff_timeout
    return @diff_timeout if @diff_timeout && cache?
    @diff_timeout = Gitorious::Configuration.get("merge_request_diff_timeout", 10).to_i
  end

  def self.dot_org?
    @is_gitorious_org = Gitorious::Configuration.get("is_gitorious_dot_org", false)
  end

  def self.git_binary
    return @git_binary if @git_binary && cache?
    @git_binary = Gitorious::Configuration.get("git_binary", "/usr/bin/env git")
  end

  def self.git_version
    return @git_version if @git_version && cache?
    @git_version = Gitorious::Configuration.get("git_version")
  end

  def self.site_name
    return @site_name if @site_name && cache?
    @site_name = Gitorious::Configuration.get("site_name", "Gitorious")
  end

  def self.registrations_enabled?
    Gitorious::Configuration.get("enable_registrations", Gitorious.public?)
  end

  def self.max_tarball_size
    return @max_tarball_size if @max_tarball_size && cache?
    mts = Gitorious::Configuration.get("max_tarball_size", 0)
    return mts.to_i * 1024 if mts =~ /k$/i
    return mts.to_i * 1024 * 1024 if mts =~ /m$/i
    return mts.to_i * 1024 * 1024 * 1024 if mts =~ /g$/i
    @max_tarball_size = mts.to_i
  end

  def self.tarballable?(repository)
    return true if max_tarball_size == 0 || repository.disk_usage.nil?
    return repository.disk_usage <= max_tarball_size
  end

  def self.configured?
    @configured
  end

  def self.configured!
    @configured = true
  end

  def self.restrict_team_creation_to_site_admins?
    Gitorious::Configuration.get("only_site_admins_can_create_teams")
  end

  def self.executor
    return @executor if @executor

    if Rails.env.test?
      require 'gitorious/test_executor'
      @executor = TestExecutor.new
    else
      require 'gitorious/command_executor'
      @executor = CommandExecutor.new
    end
  end

  def self.mirrors
    return @mirrors if @mirrors
    @mirrors = Gitorious::MirrorManager.new(Gitorious::Configuration.get('mirrors', []))
  end

  private
  def self.cache?
    return Rails.env.production? if defined?(Rails)
    false
  end
end

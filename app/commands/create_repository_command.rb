# encoding: utf-8
#--
#   Copyright (C) 2013 Gitorious AS
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
require "virtus"

class NewRepositoryInput
  include Virtus
  attribute :name, String
  attribute :description, String
  attribute :merge_requests_enabled, Boolean, :default => true
  attribute :private, Boolean, :default => false
end

class CreateRepositoryCommand
  def initialize(app, project = nil, user = nil, options = {})
    @app = app
    @project = project
    @user = user
    @options = options
  end

  def build(params)
    @private = params.private
    repository = @project.repositories.new({
        :name => params.name,
        :description => params.description,
        :merge_requests_enabled => params.merge_requests_enabled
      })
    repository.kind = @options[:kind] || 0
    repository.owner = @options[:owner] || @project.owner
    repository.user = @user
    repository
  end

  def private?
    @private
  end

  def create_owner_committership(repository)
    repository.committerships.create_for_owner!(repository.owner)
  end

  # Used by clones and tracking repos
  def initialize_membership(repo)
    return if repo.parent.public?
    repo.make_private
    repo.parent.content_memberships.each { |m| repo.add_member(m.member) }
  end
end

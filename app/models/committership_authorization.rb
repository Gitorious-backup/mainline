# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious AS
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
require "gitorious/authorization/typed_authorization"

class CommittershipAuthorization < Gitorious::Authorization::TypedAuthorization
  ### Abilities
  ability :can_read
  ability :can_edit

  def can_read_project?(user, project)
    return true if !GitoriousConfig["enable_private_repositories"]
    return true if project.owner == user
    return true if project.project_memberships.count == 0
    project.project_memberships.any? { |m| is_member?(user, m.member) }
  end

  def can_read_message?(user, message)
    [message.sender, message.recipient].include?(user)
  end

  # TODO: Needs more polymorphism
  def can_push?(user, repository)
    if repository.wiki?
      can_write_to_wiki?(user, repository)
    else
      committers(repository).include?(user)
    end
  end

  def can_delete?(candidate, repository)
    admin?(candidate, repository)
  end

  def can_edit_comment?(user, comment)
    comment.creator?(user) && comment.recently_created?
  end

  def can_request_merge?(user, repository)
    !repository.mainline? && can_push?(user, repository)
  end

  def can_resolve_merge_request?(user, merge_request)
    return false unless user.is_a?(User)
    return true if user === merge_request.user
    return reviewers(merge_request.target_repository).include?(user)
  end

  def can_reopen_merge_request?(user, merge_request)
    merge_request.can_reopen? && can_resolve_merge_request?(user, merge_request)
  end

  ### Roles

  def committer?(candidate, repository)
    candidate.is_a?(User) ? committers(repository).include?(candidate) : false
  end

  def reviewer?(candidate, repository)
    candidate.is_a?(User) ? reviewers(repository).include?(candidate) : false
  end

  def is_member?(candidate, thing)
    candidate == thing || (thing.respond_to?(:member?) && thing.member?(candidate))
  end

  ###

  def repository_admin?(candidate, repository)
    candidate.is_a?(User) ? administrators(repository).include?(candidate) : false
  end

  def project_admin?(candidate, project)
    admin?(candidate, project.owner)
  end

  def group_admin?(candidate, group)
    group.user_role(candidate) == Role.admin
  end

  def group_committer?(candidate, group)
    [Role.admin, Role.member].include?(group.user_role(candidate))
  end

  def site_admin?(user)
    user.is_a?(User) && user.is_admin
  end

  # returns an array of users who have commit bits to this repository either
  # directly through the owner, or "indirectly" through the associated
  # groups
  def committers(repository)
    repository.committerships.committers.map{|c| c.members }.flatten.compact.uniq
  end

  # Returns a list of Users who can review things (as per their Committership)
  def reviewers(repository)
    repository.committerships.reviewers.map{|c| c.members }.flatten.compact.uniq
  end

  # The list of users who can admin this repo, either directly as
  # committerships or indirectly as members of a group
  def administrators(repository)
    repository.committerships.admins.map{|c| c.members }.flatten.compact.uniq
  end

  def review_repositories(user)
    user.committerships.reviewers
  end

  private
  def can_write_to_wiki?(user, repository)
    case repository.wiki_permissions
    when Repository::WIKI_WRITABLE_EVERYONE
      return true
    when Repository::WIKI_WRITABLE_PROJECT_MEMBERS
      return repository.project.member?(user)
    end
  end
end
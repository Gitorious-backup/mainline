# encoding: utf-8
#--
#   Copyright (C) 2012-2013 Gitorious AS
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
require "presenters/project_presenter"

class RepositoryPresenter
  def initialize(repository)
    @repository = repository
  end

  def id; repository.id; end
  def name; repository.name; end
  def gitdir; repository.gitdir; end
  def to_param; repository.to_param; end
  def path_segment; repository.path_segment; end
  def full_repository_path; repository.full_repository_path; end
  def head_candidate_name; repository.head_candidate_name; end

  def open_merge_request_count
    repository.open_merge_requests.count
  end

  def slug
    "#{project.slug}/#{name}"
  end

  def project
    @project ||= ProjectPresenter.new(@repository.project)
  end

  private
  def repository; @repository; end
end

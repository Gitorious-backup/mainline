# encoding: utf-8
#--
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
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

module FavoritesHelper
  def favorite_button(watchable)
    if logged_in? && favorite = current_user.favorites.detect{|f| f.watchable == watchable}
      link = destroy_favorite_link_to(favorite, watchable)
    else
      link = create_favorite_link_to(watchable)
    end

    content_tag(:div, link, :class => "white-button round-10 small-button favorite")
  end
  
  def create_favorite_link_to(watchable)
    class_name = watchable.class.name
    link_to("Start watching",
      favorites_path(:watchable_id => watchable.id,:watchable_type => class_name),
      :method => :post, :"data-request-method" => "post",
      :class => "watch-link disabled round-10",
      :id => "watch_#{class_name.downcase}_#{watchable.id}"
      )
  end

  def destroy_favorite_link_to(favorite, watchable)
    link_to("Stop watching",
      favorite_path(favorite),
      :method => :delete, :"data-request-method" => "delete",
      :class => "watch-link enabled round-10")
  end

  # Builds a link to the target of a favorite event
  def link_to_watchable(watchable)
    case watchable
    when Repository
      link_to(repo_title(watchable, watchable.project), repo_owner_path(watchable, [watchable.project, watchable]))
    when MergeRequest
      link_to(h(truncate(watchable.summary, :length => 32)),
        repo_owner_path(watchable.target_repository,
          [watchable.source_repository.project,
           watchable.target_repository,
          watchable]))
    else
      link_to(h(watchable.title), watchable)
    end
  end


end

# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious AS
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 David A. Cuadrado <krawek@gmail.com>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#   Copyright (C) 2009 Fabio Akita <fabio.akita@gmail.com>
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

class SiteController < ApplicationController
  skip_before_filter :public_and_logged_in, :only => [:index, :about, :faq, :contact, :tos, :privacy_policy]
  before_filter :login_required, :only => [:dashboard]
  renders_in_site_specific_context :except => [:about, :faq, :contact, :tos, :privacy_policy]
  renders_in_global_context :only => [:about, :faq, :contact, :tos, :privacy_policy]

  def index
    if !current_site.subdomain.blank?
      render_site_index
    else
      render_global_index
    end
  end

  def public_timeline
    render_public_timeline
  end

  def dashboard
    redirect_to current_user
  end

  def about
    render :about, :layout => "ui3"
  end

  def faq
    render :faq, :layout => "ui3"
  end

  def contact
    render :contact, :layout => "ui3"
  end

  protected

  # Render a Site-specific index template
  def render_site_index
    all_projects = current_site.projects.order("created_at asc")
    @projects = filter_authorized(current_user, all_projects)
    @teams = Group.all_participating_in_projects(@projects)
    @top_repository_clones = filter(Repository.most_active_clones_in_projects(@projects))
    @latest_events = filter(Event.latest_in_projects(25, @projects.map{|p| p.id }))
    render "site/#{current_site.subdomain}/index"
  end

  def render_public_timeline
    @projects = filter(Project.order("id desc").limit(10))
    @top_repository_clones = filter(Repository.most_active_clones)
    @active_projects = filter(Project.most_active_recently(15))
    @active_users = User.most_active
    @active_groups = Group.most_active
    @latest_events = filter(Event.latest(25))
    render :template => "site/index", :layout => 'ui3'
  end

  def render_dashboard
    @user = current_user

    render :template => "site/dashboard", :layout => 'ui3', :locals => {
      :user => current_user,
      :events => events,
      :user_events => user_events,
      :projects => projects,
      :repositories => repositories,
      :favorites => favorites,
      :atom_auto_discovery_url => atom_auto_discovery_url
    }
  end

  # for dashboard
  #
  # TODO: extract this into some Dashboard-context object
  def events
    @events ||= filter_paginated(params[:page], Event.per_page) { |page|
      current_user.paginated_events_in_watchlist(:page => page)
    }
  end

  # needed by dashboard
  #
  # TODO: extract this into some Dashboard-context object
  def projects
    @projects ||= filter(current_user.projects.includes(:tags, { :repositories => :project }))
  end

  # needed by dashboard
  #
  # TODO: extract this into some Dashboard-context object
  def repositories
    @repositories ||= filter(current_user.commit_repositories)
  end

  # needed by dashboard
  #
  # TODO: extract this into some Dashboard-context object
  def atom_auto_discovery_url
    @atom_auto_discovery_url ||= user_watchlist_path(current_user, :format => :atom)
  end

  # needed by dashboard
  #
  # TODO: extract this into some Dashboard-context object
  def favorites
    @favorites ||= filter(current_user.favorites.all(:include => :watchable))
  end

  # needed by dashboard
  #
  # TODO: extract this into some Dashboard-context object
  # TODO: this is identical as UsersController#paginated_events
  def user_events
    paginate(page_free_redirect_options) do
      filter_paginated(params[:page], FeedItem.per_page) do |page|
        current_user.events.excluding_commits.paginate(
          :page => page,
          :order => "events.created_at desc",
          :include => [:user, :project]
        )
      end
    end
  end

  def render_gitorious_dot_org_in_public
    @feed_items = Rails.cache.fetch("blog_feed:feed_items", :expires_in => 1.hour) do
      unless Rails.env.test?
        BlogFeed.new("http://blog.gitorious.org/feed/").fetch
      else
        []
      end
    end
    render :template => "site/public_index", :layout => "ui3"
  end

  # Render the global index template
  def render_global_index
    if logged_in?
      render_dashboard
    elsif Gitorious.dot_org?
      render_gitorious_dot_org_in_public
    else
      render_public_timeline
    end
  end
end

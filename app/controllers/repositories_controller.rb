# encoding: utf-8
#--
#   Copyright (C) 2012-2013 Gitorious AS
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2009 Fabio Akita <fabio.akita@gmail.com>
#   Copyright (C) 2008 David A. Cuadrado <krawek@gmail.com>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#   Copyright (C) 2007, 2008 Johan Sørensen <johan@johansorensen.com>
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

class RepositoriesController < ApplicationController
  include Gitorious::Messaging::Publisher
  before_filter :login_required, :except => [:index, :show, :writable_by, :repository_config]
  before_filter :find_repository_owner, :except => [:writable_by, :repository_config]
  before_filter :unauthorized_repository_owner_and_project, :only => [:writable_by, :repository_config]
  before_filter :find_and_require_repository_adminship,
  :only => [:edit, :update, :confirm_delete, :destroy]
  always_skip_session :only => [:repository_config, :writable_by]
  renders_in_site_specific_context :except => [:writable_by, :repository_config]

  def index
    if term = params[:filter]
      @repositories = filter(@project.search_repositories(term))
    else
      @repositories = paginate(page_free_redirect_options) do
        filter_paginated(params[:page], Repository.per_page) do |page|
          @owner.repositories.regular.paginate(:include => [:user, :events, :project], :page => page)
        end
      end
    end

    return if @repositories.count == 0 && params.key?(:page)

    respond_to do |wants|
      wants.html
      wants.xml {render :xml => @repositories.to_xml}
      wants.json {render :json => RepositorySerializer.new(self).to_json(@repositories)}
    end
  end

  def show
    repository = repository_to_clone

    page = JustPaginate.page_value(params[:page])
    all_events = repository.events.all
    if Gitorious.private_repositories?
      event_count = filter(all_events).count
      events, total_pages = JustPaginate.paginate(page, Event.per_page, event_count) do |index_range|
        filter(repository.events.all).slice(index_range)
      end
    else
      event_count = all_events.count
      events, total_pages = JustPaginate.paginate(page, Event.per_page, event_count) do |index_range|
        repository.events.all( :offset => index_range.first, :limit => index_range.count)
      end
    end

    response.headers["Refresh"] = "5" unless repository.ready

    respond_to do |format|
      format.html do
        render(:action => :show, :layout => "ui3/layouts/layout", :locals => {
            :repository => RepositoryPresenter.new(repository),
            :ref => repository.head_candidate_name,
            :events => events,
            :page => page,
            :total_pages => total_pages,
            :atom_auto_discovery_url => project_repository_path(repository.project, repository, :format => :atom),
            :atom_auto_discovery_title => "#{repository.title} ATOM feed"
          })
      end
      format.xml  { render :xml => repository }
      format.atom {  }
    end
  end

  def new
    outcome = PrepareProjectRepository.new(self, @project, current_user).execute({})
    pre_condition_failed(outcome)
    outcome.success { |result| render_form(result, @project, @owner) }
  end

  def create
    cmd = CreateProjectRepository.new(self, @project, current_user)
    outcome = cmd.execute({ :private => params[:private] }.merge(params[:repository]))

    pre_condition_failed(outcome) do |f|
      f.when(:admin_required) { |c| respond_denied_and_redirect_to(@project) }
    end

    outcome.failure do |repository|
      render_form(repository, @project, @owner)
    end

    outcome.success do |result|
      flash[:success] = I18n.t("repositories_controller.create_success")
      redirect_to([result.project, result])
    end
  end

  def edit
    @root = Breadcrumb::EditRepository.new(@repository)
    @groups = Team.for_user(current_user)
    @heads = @repository.git.heads
  end

  def update
    @root = Breadcrumb::EditRepository.new(@repository)
    @groups = Team.for_user(current_user)
    @heads = @repository.git.heads

    Repository.transaction do
      unless params[:repository][:owner_id].blank?
        new_owner = @groups.detect {|group| group.id == params[:repository][:owner_id].to_i}
        @repository.change_owner_to!(new_owner)
      end

      @repository.head = params[:repository][:head]

      @repository.log_changes_with_user(current_user) do
        @repository.replace_value(:name, params[:repository][:name])
        @repository.replace_value(:description, params[:repository][:description], true)
      end
      @repository.deny_force_pushing = params[:repository][:deny_force_pushing]
      @repository.notify_committers_on_new_merge_request = params[:repository][:notify_committers_on_new_merge_request]
      @repository.merge_requests_enabled = params[:repository][:merge_requests_enabled]
      @repository.save!
      flash[:success] = "Repository updated"
      redirect_to [@repository.project, @repository]
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    render :action => "edit"
  end

  # Used internally to check write permissions by gitorious
  def writable_by
    @repository = @owner.cloneable_repositories.find_by_name_in_project!(params[:id], @containing_project)
    user = User.find_by_login(params[:username])

    if user && result = /^refs\/merge-requests\/(\d+)$/.match(params[:git_path].to_s)
      # git_path is a merge request
      begin
        if merge_request = @repository.merge_requests.find_by_sequence_number!(result[1]) and (merge_request.user == user)
          render :text => "true" and return
        end
      rescue ActiveRecord::RecordNotFound # No such merge request
      end
    elsif user && can_push?(user, @repository)
      render :text => "true" and return
    end
    render :text => 'false' and return
  end

  def repository_config
    @repository = @owner.cloneable_repositories.find_by_name_in_project!(params[:id],
      @containing_project)
    authorize_configuration_access(@repository)
    config_data = "real_path:#{@repository.real_gitdir}\n"
    config_data << "force_pushing_denied:"
    config_data << (@repository.deny_force_pushing? ? 'true' : 'false')
    headers["Cache-Control"] = "public, max-age=600"

    render :text => config_data, :content_type => "text/x-yaml"
  end

  def confirm_delete
    @repository = repository_to_clone
    unless can_delete?(current_user, @repository)
      flash[:error] = I18n.t "repositories_controller.adminship_error"
      redirect_to(@owner) and return
    end
  end

  def destroy
    @repository = repository_to_clone
    if can_delete?(current_user, @repository)
      repo_name = @repository.name
      flash[:notice] = I18n.t "repositories_controller.destroy_notice"
      @repository.destroy
      @repository.project.create_event(Action::DELETE_REPOSITORY, @owner,
        current_user, repo_name)
    else
      flash[:error] = I18n.t "repositories_controller.destroy_error"
    end
    redirect_to @owner
  end

  private
  def render_form(repository, project, owner)
    render(:action => :new, :locals => {
        :repository => repository,
        :project => project,
        :owner => owner
      })
  end

  def find_and_require_repository_adminship
    @repository = @owner.repositories.find_by_name_in_project!(params[:id],
      @containing_project)
    unless admin?(current_user, authorize_access_to(@repository))
      respond_denied_and_redirect_to(project_repository_path(@repository.project, @repository))
      return
    end
  end

  def respond_denied_and_redirect_to(target)
    respond_to do |format|
      format.html {
        flash[:error] = I18n.t "repositories_controller.adminship_error"
        redirect_to(target)
      }
      format.xml  {
        render :text => I18n.t( "repositories_controller.adminship_error"),
        :status => :forbidden
      }
    end
  end

  def unauthorized_repository_owner_and_project
    if params[:user_id]
      @owner = User.find_by_login!(params[:user_id])
      @containing_project = Project.find_by_slug!(params[:project_id]) if params[:project_id]
    elsif params[:group_id]
      @owner = Group.find_by_name!(params[:group_id])
      @containing_project = Project.find_by_slug!(params[:project_id]) if params[:project_id]
    elsif params[:project_id]
      @owner = Project.find_by_slug!(params[:project_id])
      @project = @owner
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def authorize_configuration_access(repository)
    return true if !Gitorious.private_repositories?
    if !can_read?(User.find_by_login(params[:username]), repository)
      raise Gitorious::Authorization::UnauthorizedError.new(request.fullpath)
    end
  end

  def repository_to_clone
    repo = @owner.repositories.find_by_name_in_project!(params[:id], @containing_project)
    authorize_access_to(repo)
  end

  def pre_condition_failed(outcome)
    super(outcome) do |f|
      f.when(:admin_required) { |c| respond_denied_and_redirect_to(@project) }
    end
  end
end

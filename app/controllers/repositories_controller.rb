# encoding: utf-8
#--
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2007, 2008 Johan Sørensen <johan@johansorensen.com>
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

class RepositoriesController < ApplicationController
  before_filter :login_required, :except => [:index, :show, :readable_by, :writable_by, :config]
  before_filter :find_repository_owner
  before_filter :require_adminship, :only => [:edit, :update, :new, :create, :edit, :update]
  before_filter :require_user_has_ssh_keys, :only => [:clone, :create_clone]
  before_filter :only_projects_can_add_new_repositories, :only => [:new, :create]
  before_filter :find_repository, :only => [:show,:edit,:update,:delete,:destroy,:readable_by, :writable_by, :config]
  
  skip_before_filter :public_and_logged_in, :only => [:readable_by, :writable_by, :config]
  
  renders_in_site_specific_context :except => [:writable_by, :config]
  
  def index
    @repositories = @owner.repositories.find(:all, :include => [:user, :events, :project])
    respond_to do |wants|
      wants.html
      wants.xml {render :xml => @repositories.to_xml}
    end
  end
    
  def show
    @root = @repository
    @events = @repository.events.top.paginate(:all, :page => params[:page], 
      :order => "created_at desc")
    
    @atom_auto_discovery_url = repo_owner_path(@repository, :project_repository_path,
                                  @repository.project, @repository, :format => :atom)
    response.headers['Refresh'] = "5" unless @repository.ready
    
    respond_to do |format|
      format.html
      format.xml  { render :xml => @repository }
      format.atom {  }
    end
  end
  
  def new
    @repository = @project.repositories.new
    @root = Breadcrumb::NewRepository.new(@project)
    @repository.kind = Repository::KIND_PROJECT_REPO
    @repository.owner = @project.owner
    if @project.repositories.mainlines.count == 0
      @repository.name = @project.slug
    end
  end
  
  def create
    @repository = @project.repositories.new(params[:repository])
    @root = Breadcrumb::NewRepository.new(@project)
    @repository.kind = Repository::KIND_PROJECT_REPO
    @repository.owner = @project.owner
    @repository.user = current_user
    
    if @repository.save
      flash[:success] = I18n.t("repositories_controller.create_success")
      redirect_to [@repository.project_or_owner, @repository]
    else
      render :action => "new"
    end
  end
  
  undef_method :clone
  
  def clone
    @repository_to_clone = @owner.repositories.find_by_name_in_project!(params[:id], @containing_project)
    @root = Breadcrumb::CloneRepository.new(@repository_to_clone)
    unless @repository_to_clone.has_commits?
      flash[:error] = I18n.t "repositories_controller.new_clone_error"
      redirect_to [@owner, @repository_to_clone]
      return
    end
    @repository = Repository.new_by_cloning(@repository_to_clone, current_user.login)
  end
  
  def create_clone
    @repository_to_clone = @owner.repositories.find_by_name_in_project!(params[:id], @containing_project)
    @root = Breadcrumb::CloneRepository.new(@repository_to_clone)
    unless @repository_to_clone.has_commits?
      respond_to do |format|
        format.html do
          flash[:error] = I18n.t "repositories_controller.create_clone_error"
          redirect_to [@owner, @repository_to_clone]
        end
        format.xml do 
          render :text => I18n.t("repositories_controller.create_clone_error"), 
            :location => [@owner, @repository_to_clone], :status => :unprocessable_entity
        end
      end
      return
    end

    @repository = Repository.new_by_cloning(@repository_to_clone)
    @repository.name = params[:repository][:name]
    @repository.user = current_user
    case params[:repository][:owner_type]
    when "User"
      @repository.owner = current_user
      @repository.kind = Repository::KIND_USER_REPO
    when "Group"
      @repository.owner = current_user.groups.find(params[:repository][:owner_id])
      @repository.kind = Repository::KIND_TEAM_REPO
    end
    
    respond_to do |format|
      if @repository.save
        @owner.create_event(Action::CLONE_REPOSITORY, @repository, current_user, @repository_to_clone.id)
        
        location = repo_owner_path(@repository, :project_repository_path, @owner, @repository)
        format.html { redirect_to location }
        format.xml  { render :xml => @repository, :status => :created, :location => location } 
      else
        format.html { render :action => "clone" }
        format.xml  { render :xml => @repository.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def edit
    @root = Breadcrumb::EditRepository.new(@repository)
    @groups = current_user.groups
    @heads = @repository.git.heads
  end
  
  def update
    @root = Breadcrumb::EditRepository.new(@repository)
    @groups = current_user.groups
    @heads = @repository.git.heads
    
    Repository.transaction do
      unless params[:repository][:owner_id].blank?
        @repository.change_owner_to!(current_user.groups.find(params[:repository][:owner_id]))
      end
      
      @repository.head = params[:repository][:head]

      @repository.log_changes_with_user(current_user) do
        @repository.replace_value(:name, params[:repository][:name])
        @repository.replace_value(:description, params[:repository][:description])
      end
      @repository.deny_force_pushing = params[:repository][:deny_force_pushing]
      @repository.notify_committers_on_new_merge_request = params[:repository][:notify_committers_on_new_merge_request]
      @repository.save!
      flash[:success] = "Repository updated"
      redirect_to [@repository.project_or_owner, @repository]
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    render :action => "edit"
  end
  
  # Used internally to check read permissions by gitorious and git-daemon
  def readable_by
    result = nil
    
    if @repository.project.public?
      result = true
    else
      user   = User.find_by_login(params[:username])
      result = user && user.can_read_from?(@repository)
    end
    
    render :text => result ? 'true' : 'false'
  end
  
  # Used internally to check write permissions by gitorious
  def writable_by
    user   = User.find_by_login(params[:username])
    result = nil
    
    if user.nil?
      result = false
    elsif result = /^refs\/merge-requests\/(\d+)$/.match(params[:git_path].to_s)
      # git_path is a merge request
      merge_request = MergeRequest.find_by_id(result[1])
      result = merge_request && merge_request.user == user
    else
      result = user.can_write_to?(@repository)
    end
    render :text => result ? 'true' : 'false'
  end
  
  
  def config
    render :text => {
      "real_path" => @repository.real_gitdir,
      "force_pushing_denied" => @repository.deny_force_pushing?
    }.to_yaml
  end
  
  def confirm_delete
    unless @repository.can_be_deleted_by?(current_user)
      flash[:error] = I18n.t "repositories_controller.adminship_error"
      redirect_to(@owner) and return
    end
  end
  
  def destroy
    if @repository.can_be_deleted_by?(current_user)
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
  
    def find_repository
      @repository = @owner.repositories.find_by_name_in_project!(params[:id], @containing_project)
    end
    
    def require_adminship
      unless @owner.admin?(current_user)
        respond_to do |format|
          format.html { 
            flash[:error] = I18n.t "repositories_controller.adminship_error"
            redirect_to(@owner) 
          }
          format.xml  { 
            render :text => I18n.t( "repositories_controller.adminship_error"), 
                    :status => :forbidden 
          }
        end
        return
      end
    end
    
    def only_projects_can_add_new_repositories
      if !@owner.is_a?(Project)
        respond_to do |format|
          format.html { 
            flash[:error] = I18n.t("repositories_controller.only_projects_create_new_error")
            redirect_to(@owner) 
          }
          format.xml  { 
            render :text => I18n.t( "repositories_controller.only_projects_create_new_error"), 
                    :status => :forbidden 
          }
        end
        return
      end
    end
end

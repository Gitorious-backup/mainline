# encoding: utf-8
#--
#   Copyright (C) 2011-2012 Gitorious AS
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

require "test_helper"

class CommitDiffsControllerTest < ActionController::TestCase
  def setup
    @project = projects(:johans)
    @repository = @project.repositories.mainlines.first
    @repository.update_attribute(:ready, true)
    @sha = "3fa4e130fa18c92e3030d4accb5d3e0cadd40157"
    Repository.any_instance.stubs(:full_repository_path).returns(grit_test_repo("dot_git"))
    @grit = Grit::Repo.new(grit_test_repo("dot_git"), :is_bare => true)
    Repository.any_instance.stubs(:git).returns(@grit)
  end

  context "index" do
    should "not show diffs for the initial commit" do
      commit = @grit.commit(@sha)
      commit.stubs(:parents).returns([])
      @grit.expects(:commit).returns(commit)
      get :index, params

      assert_equal [], assigns(:diffs)
      assert_select "#content p", /This is the initial commit in this repository/
    end

    should "show diffs for successive commits" do
      get :index, params("5a0943123f6872e75a9b1dd0b6519dd42a186fda")
      assert_response :success
    end

    should "yield 404 if commit does not exist" do
      get :index, params("0000000")
      assert_response 404
    end

    should "not touch the session object" do
      Gitorious::Configuration.override("enable_private_repositories" => false) do
        ApplicationController.any_instance.expects(:authorize_access_with_private_repositories_enabled).never
        get :index, params("5a0943123f6872e75a9b1dd0b6519dd42a186fda")
      end
    end

    should "not bypass authorization if private repositories are enabled" do
      Gitorious::Configuration.override("enable_private_repositories" => true) do
        @controller.expects(:authorize_access_with_private_repositories_enabled).with(@project).returns(@project)
        @controller.expects(:authorize_access_with_private_repositories_enabled).with(@repository).returns(@repository)
        get :index, params("5a0943123f6872e75a9b1dd0b6519dd42a186fda")
      end
    end
  end

  context "Comparing arbitrary commits" do
    should "pick the correct commits" do
      Grit::Commit.expects(:diff).with(@repository.git, OTHER_SHA, @sha).returns([])
      get :compare, compare_params
      assert_response :success
    end

    should "render not found when given commit does not exist" do
      get :compare, compare_params.merge(:id => "does-not-exist")
      assert_response :not_found
    end
  end

  context "With private projects" do
    setup do
      enable_private_repositories
    end

    should "disallow unauthorized access to diffs" do
      get :index, params
      assert_response 403
    end

    should "allow authorized access to diffs" do
      login_as :johan
      get :index, params
      assert_response 200
    end

    should "disallow unauthorized access to compare view" do
      get :compare, compare_params
      assert_response 403
    end

    should "allow authorized access to compare view" do
      login_as :johan
      get :compare, compare_params
      assert_response 200
    end
  end

  context "With private repositories" do
    setup do
      enable_private_repositories(@repository)
    end

    should "disallow unauthorized access to diffs" do
      get :index, params
      assert_response 403
    end

    should "allow authorized access to diffs" do
      login_as :johan
      get :index, params
      assert_response 200
    end

    should "disallow unauthorized access to compare view" do
      get :compare, compare_params
      assert_response 403
    end

    should "allow authorized access to compare view" do
      login_as :johan
      get :compare, compare_params
      assert_response 200
    end
  end

  private
  def params(sha = @sha)
    { :project_id => @project.to_param,
      :repository_id => @repository.to_param,
      :id => sha }
  end

  def compare_params
    { :project_id => @project.slug,
      :repository_id => @repository.name,
      :from_id => OTHER_SHA,
      :id => @sha,
      :fragment => "true" }
  end
end

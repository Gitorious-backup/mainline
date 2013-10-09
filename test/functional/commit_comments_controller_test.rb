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

class CommitCommentsControllerTest < ActionController::TestCase
  def setup
    @project = projects(:johans)
    @repository = @project.repositories.mainlines.first
    @repository.update_attribute(:ready, true)
    @sha = "3fa4e130fa18c92e3030d4accb5d3e0cadd40157"
  end

  context "index" do
    should "list comments" do

    end
  end

  # context "index" do
  #   should "display comments" do
  #     comment = create_comment
  #     get(:index, params)

  #     assert_match comment.body, @response.body
  #   end

  #   should "have a different last-modified if there is a comment" do
  #     create_comment
  #     get(:index, params)

  #     assert_response :success
  #     assert_not_equal "Fri, 18 Apr 2008 23:26:07 GMT", @response.headers["Last-Modified"]
  #   end
  # end

  context "With private projects" do
    setup do
      enable_private_repositories
    end

    should "disallow unauthorized user from listing comments" do
      comment = create_comment
      get(:index, params)
      assert_response 403
    end

    should "allow authorized user to list comments" do
      login_as :johan
      comment = create_comment
      get(:index, params)
      assert_response 200
    end
  end

  context "With private repositories" do
    setup do
      enable_private_repositories(@repository)
    end

    should "disallow unauthorized user from listing comments" do
      comment = create_comment
      get(:index, params)
      assert_response 403
    end

    should "allow authorized user to list comments" do
      login_as :johan
      comment = create_comment
      get(:index, params)
      assert_response 200
    end
  end

  private
  def create_comment
    Comment.create!({ :user => users(:johan),
                      :body => "foo",
                      :sha1 => @sha,
                      :target => @repository,
                      :project => @repository.project })
  end

  def params
    { :project_id => @project.slug,
      :repository_id => @repository.name,
      :id => @sha }
  end
end

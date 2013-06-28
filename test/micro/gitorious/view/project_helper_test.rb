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
require "fast_test_helper"
require "gitorious/view/project_helper"

class Gitorious::View::ProjectHelperTest < MiniTest::Spec
  include Gitorious::View::ProjectHelper

  describe "#project_description" do
    it "returns HTML-formatted description" do
      project = Project.new(:description => "Yo, here")
      assert_equal "<p>Yo, here</p>", project_description(project)
    end
  end
end
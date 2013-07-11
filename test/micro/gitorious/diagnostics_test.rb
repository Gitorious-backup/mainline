# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious
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
require "gitorious/diagnostics"

class DiagnosticsTest < MiniTest::Spec
  include Gitorious::Diagnostics

  describe "Self-diagnostics" do
    it "detects if any current ps entry contains given string" do
      assert atleast_one_process_name_matching("test")
    end

    it "verifies file existence" do
      assert !file_present?("/tmp/file_not_there.txt")
      assert file_present?(__FILE__)
    end

    it "verifies dir existence" do
      assert !dir_present?("/dir_not_there")
      assert dir_present?(File.dirname(__FILE__))
    end

    it "verifies user existence" do
      assert !user_exists?("sir_not_in_this_movie")
      assert user_exists?(me)
    end

    it "verifies current user identity" do
      assert !current_user?("sir_not_in_this_movie")
      assert current_user?(me)
    end

    it "verifies file ownership" do
      assert !owned_by_user?("/etc/hosts", me)
      assert !owned_by_user?(__FILE__, "root")
      assert owned_by_user?(__FILE__, me)
    end

  end

  def me
    ENV['USER']
  end
end

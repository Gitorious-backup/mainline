# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious AS
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
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

class SearchesController < ApplicationController
  PER_PAGE = 30
  helper :all
  renders_in_global_context

  def show
    unless params[:q].blank?
      @all_results = nil  # The unfiltered search result from TS
      @results = paginate(page_free_redirect_options) do
        filter_paginated(params[:page], PER_PAGE) do |page|
          @all_results = ThinkingSphinx.search({ :query => params[:q],
                                             :page => page,
                                             :per_page => PER_PAGE })
        end
      end

      unfiltered_results_length = @all_results.nil? ? 0 : @all_results.length
      filtered_results_length = @results.length
      @total_entries = @all_results.total_entries - (unfiltered_results_length - filtered_results_length)
    end
  end
end

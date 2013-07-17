# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious AS
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
require "pathname"

class RepositoryRoot
  def self.default_base_path
    @default_base_path
  end

  def self.default_base_path=(path)
    @default_base_path = path
  end

  def self.shard_dirs?
    !!@shard_dirs
  end

  def self.shard_dirs!
    @shard_dirs = true
  end

  def self.expand(path)
    (Pathname(RepositoryRoot.default_base_path) + path).expand_path
  end

  def self.relative_path(path)
    Pathname(path).relative_path_from(Pathname(RepositoryRoot.default_base_path))
  end
end

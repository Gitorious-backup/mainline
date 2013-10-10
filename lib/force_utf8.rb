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

module ForceUTF8
  def force_utf8(str)
    return nil if str.nil?

    if str.respond_to?(:force_encoding)
      str.force_encoding("UTF-8")
      if str.valid_encoding?
        str
      else
        str.encode("binary", :invalid => :replace, :undef => :replace).encode("utf-8")
      end
    else
      str.mb_chars
    end
  end
end

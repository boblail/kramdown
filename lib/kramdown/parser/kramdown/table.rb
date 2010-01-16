# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2010 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'kramdown/parser/kramdown/blank_line'
require 'kramdown/parser/kramdown/eob'
require 'kramdown/parser/kramdown/horizontal_rule'

module Kramdown
  module Parser
    class Kramdown

      TABLE_SEP_LINE = /^#{OPT_SPACE}(\||\+)-[+|-]*[ \t]*\n/
      TABLE_HSEP_ALIGN = /[ \t]*(:?)-+(:?)[ \t]*/
      TABLE_HSEP_LINE = /^#{OPT_SPACE}((?:(?:\||\+)#{TABLE_HSEP_ALIGN})+)(?:\||\+)?[ \t]*\n/
      TABLE_FSEP_LINE = /^#{OPT_SPACE}(\||\+)=[+|=]*[ \t]*\n/
      TABLE_ROW_LINE = /^#{OPT_SPACE}\|(.*?)[ \t]*\n/
      TABLE_START = /^#{OPT_SPACE}\|(?:-|(?!=))/

      # Parse the table at the current location.
      def parse_table
        orig_pos = @src.pos
        table = Element.new(:table, nil, :alignment => [])

        @src.scan(TABLE_SEP_LINE)

        rows = []
        has_footer = false
        columns = 0

        add_container = lambda do |type, force|
          if force || type != :tbody || !has_footer
            cont = Element.new(type)
            cont.children, rows = rows, []
            table.children << cont
          end
        end

        while !@src.eos?
          if @src.scan(TABLE_HSEP_LINE) && !rows.empty?
            if table.options[:alignment].empty? && !has_footer
              add_container.call(:thead, false)
              table.options[:alignment] = @src[1].scan(TABLE_HSEP_ALIGN).map do |left, right|
                (left.empty? && right.empty? && :default) || (right.empty? && :left) || (left.empty? && :right) || :center
              end
            else # treat as separator line
              add_container.call(:tbody, false)
            end
          elsif @src.scan(TABLE_SEP_LINE) && !rows.empty?
            add_container.call(:tbody, false)
          elsif @src.scan(TABLE_FSEP_LINE)
            add_container.call(:tbody, true) if !rows.empty?
            has_footer = true
          elsif @src.scan(TABLE_ROW_LINE)
            trow = Element.new(:tr)
            cells = (@src[1] + ' ').split(/\|/)
            i = 0
            while i < cells.length - 1
              backslashes = cells[i].scan(/\\+$/).first
              if backslashes && backslashes.length % 2 == 1
                cells[i] = cells[i].chop + '|' + cells[i+1]
                cells.delete_at(i+1)
              else
                i += 1
              end
            end
            cells.pop if cells.last.strip.empty?
            cells.each do |cell_text|
              tcell = Element.new(:td)
              tcell.children << Element.new(:text, cell_text.strip)
              trow.children << tcell
            end
            columns = [columns, cells.length].max
            rows << trow
          else
            break
          end
        end

        add_container.call(has_footer ? :tfoot : :tbody, false) if !rows.empty?

        if !table.children.any? {|c| c.type == :tbody}
          warning("Found table without body - ignoring it")
          @src.pos = orig_pos
          return false
        end

        # adjust all table rows to have equal number of columns, same for alignment defs
        table.children.each do |kind|
          kind.children.each do |row|
            (columns - row.children.length).times do
              row.children << Element.new(:td)
            end
          end
        end
        table.options[:alignment] += [:default] * (columns - table.options[:alignment].length)
        @tree.children << table

        true
      end
      define_parser(:table, TABLE_START)

    end
  end
end
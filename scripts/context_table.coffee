# Ace editor plugin for Dokuwiki
# Copyright © 2011 Institut Obert de Catalunya
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Ths program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

define (require) -> (spec) ->

  new_cell = (spec) ->

    text = -> spec.content.replace(/^\ +/, '').replace(/\ +$/, '')

    update_layout = (layout, offset) ->
      padding = switch spec.align
        when 'left' then left: 1, right: 1
        when 'center' then left: 2, right: 2
        when 'right' then left: 2, right: 1
      min_length = text().length + spec.colspan + padding.left + padding.right
      target_length = 0

      for i in [0...spec.colspan]
        layout[offset+i] or= 0
        target_length += layout[offset+i]

      if min_length < target_length
        space = target_length - min_length
        switch spec.align
          when 'left'
            padding.right += space
          when 'right'
            padding.left += space
          when 'center'
            padding.left += Math.floor space / 2
            padding.right += Math.ceil space / 2
      else
        space = min_length - target_length
        for i in [0...spec.colspan]
          layout[offset+i] += Math.floor space / spec.colspan
        for i in [0...space % space.colspan]
          layout[offset+i] += 1

      padding

    cursor_position: -> 1 + Math.max 1, spec.content.replace(/\ +$/, '').length

    colspan: -> spec.colspan

    format: (layout, offset, pass) ->
      if pass >= 2 or spec.colspan == 1
        padding = update_layout layout, offset
      if pass >= 3
        space = (n) -> new Array(n + 1).join ' '
        spec.content = space(padding.left) + text() + space(padding.right)

    is_header: -> spec.is_header

    length: -> 1 + spec.content.length

    toggle_header: -> spec.is_header = not spec.is_header

    set_align: (value) -> spec.align = value

    value: ->
      sep = if spec.is_header then '^' else '|'
      sep + spec.content + new Array(spec.colspan).join sep

  new_row = (cells) ->

    columns = ->
      result = 0
      result += cell.colspan() for cell in cells
      result

    align_cell: (index, align) -> cells[index].set_align align

    columns: columns

    cursor_position: (cell) ->
      position = 0
      position += cells[i].length() for i in [0...cell]
      position + cells[cell].cursor_position()

    cursor_cell: (column) ->
      length = 0
      for i in [0...cells.length]
        length += cells[i].length()
        return i if column < length
      cells.length - 1

    fill: (n_columns) ->
      for i in [columns()...n_columns]
        cells.push new_cell
          align: 'left'
          colspan: 1
          content: '  '
          is_header: cells[cells.length - 1]?.is_header()

    format: (layout, pass) ->
      offset = 0
      for cell in cells
        cell.format layout, offset, pass
        offset += cell.colspan()

    length: -> cells.length

    move_cell_left: (index) ->
      if 1 <= index < cells.length
        cells[index-1..index] = cells[index-1..index].reverse()

    move_cell_right: (index) ->
      if 0 <= index < cells.length - 1
        cells[index..index+1] = cells[index..index+1].reverse()

    remove_cell: (index) -> cells.splice index, 1

    toggle_header: (index) -> cells[index].toggle_header()

    value: ->
      last_sep = if cells[cells.length-1].is_header() then '^' else '|'
      (cell.value() for cell in cells).join('') + last_sep

  new_table = (rows, start_row, end_row, cursor_pos) ->

    cursor_row = cursor_pos.row - start_row
    cursor_cell = rows[cursor_row].cursor_cell cursor_pos.column

    cursor_position = ->
      row: start_row + cursor_row
      column: rows[cursor_row].cursor_position cursor_cell

    format = ->
      layout = []
      normalize()
      for pass in [1..3]
        row.format layout, pass for row in rows
      update()

    has_colspans = ->
      for row in rows
        return true if row.length() != row.columns()

    normalize = ->
      columns = 0
      for row in rows
        columns = Math.max columns, row.columns()
      for row in rows
        row.fill columns
      if cursor_cell >= rows[cursor_row].length()
        cursor_cell = rows[cursor_row].length() - 1

    update = ->
      lines = (row.value() for row in rows)
      spec.ace.replace_lines start_row, end_row, lines
      spec.ace.navigate cursor_position()

    align_cell: (align) ->
      rows[cursor_row].align_cell cursor_cell, align
      format()

    move_column_left: ->
      normalize()
      if not has_colspans() and cursor_cell > 0
        row.move_cell_left cursor_cell for row in rows
        cursor_cell -= 1
      format()

    move_column_right: ->
      normalize()
      if not has_colspans() and cursor_cell < rows[cursor_row].length() - 1
        row.move_cell_right cursor_cell for row in rows
        cursor_cell += 1
      format()

    next_cell: ->
      cursor_cell += 1
      if cursor_cell == rows[cursor_row].length()
        cursor_cell = 0
        cursor_row += 1
        if cursor_row == rows.length
          rows.push new_row []
      format()

    next_row: ->
      cursor_row += 1
      if cursor_row == rows.length
        rows.push new_row []
      format()

    previous_cell: ->
      if cursor_cell > 0
        cursor_cell -= 1
      else if cursor_row > 0
        cursor_row -= 1
        cursor_cell = Infinity
      format()

    previous_row: ->
      if cursor_row > 0
        cursor_row -= 1
      format()

    remove_column: ->
      normalize()
      if not has_colspans() and rows[0].length() > 1
        row.remove_cell cursor_cell for row in rows
      format()

    toggle_header: ->
      rows[cursor_row].toggle_header cursor_cell
      format()

  parse_row = (row) ->
    cells = []
    content = null
    is_header = false

    push_cell = (colspan) ->
      if content?
        if not /^  +[^ ]/.test content
          align = 'left'
        else if /[^ ] + $/.test content
          align = 'center'
        else
          align = 'right'
        cells.push new_cell {align, colspan, content, is_header}

    parse_table_token = (token) ->
      is_separator = (i) ->
        token[i] == '|' or token[i] == '^'
      for i in [0...token.length]
        if is_separator i
          colspan = 1
          while is_separator i + 1
            colspan += 1
            i += 1
          push_cell colspan
          is_header = token[i] is '^'
          content = ''
        else
          content += token[i]

    tokens = spec.ace.get_tokens row
    return unless tokens[0]?.type is 'table'

    for token in tokens
      if token.type is 'table'
        parse_table_token token.value
      else
        content += token.value

    new_row cells

  parse_table = ->
    pos = spec.ace.cursor_position()
    start_row = pos.row
    end_row = pos.row
    rows = []

    row = parse_row pos.row
    return unless row
    rows.push row

    for i in [pos.row-1..0]
      row = parse_row i
      break unless row
      rows.push row
      start_row = i

    rows.reverse()

    for i in [pos.row+1...spec.ace.get_length()]
      row = parse_row i
      break unless row
      rows.push row
      end_row = i

    new_table rows, start_row, end_row, pos

  commands:
    alt_left: (table) -> table.move_column_left()
    alt_right: (table) -> table.move_column_right()
    ctrl_shift_d: (table) -> table.remove_column()
    menu_c: (table) -> table.align_cell 'center'
    menu_l: (table) -> table.align_cell 'left'
    menu_r: (table) -> table.align_cell 'right'
    menu_t:  (table) -> table.toggle_header()
    return: (table) -> table.next_row()
    shift_return: (table) -> table.previous_row()
    shift_tab: (table) -> table.previous_cell()
    tab: (table) -> table.next_cell()

  menu: [
    {key: 't', label: 'Toggle type'}
    {key: 'l', label: 'Align to left'}
    {key: 'c', label: 'Align to center'}
    {key: 'r', label: 'Align to right'}
  ]

  name: 'table'

  parse: parse_table
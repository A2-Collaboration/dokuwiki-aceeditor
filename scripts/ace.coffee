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
  {Range} = require 'ace/range'
  {StateHandler} = require 'ace/keyboard/state_handler'
  canon = require 'pilot/canon'

  editor = null
  session = null

  offset_to_pos = (offset) ->
    for row in [0...session.getLength()]
      row_length = session.getLine(row).length + 1
      break if offset < row_length
      offset -= row_length
    {row, column: offset}

  pos_to_offset = (pos) ->
    offset = pos.column;
    for i in [0...pos.row]
      offset += session.getLine(i).length + 1
    offset

  do ->
    {Editor} = require 'ace/editor'
    {VirtualRenderer} = require 'ace/virtual_renderer'
    {Mode} = require 'ace/mode/text'
    {Tokenizer} = require 'ace/tokenizer'
    {UndoManager} = require 'ace/undomanager'

    theme = {cssClass: 'ace-doku-' + spec.colortheme}
    renderer = new VirtualRenderer spec.element, theme
    mode = new Mode()

    editor = new Editor renderer
    editor.setReadOnly spec.readonly
    session = editor.getSession()
    session.setUndoManager new UndoManager()
    session.setTabSize 2
    mode.$tokenizer = new Tokenizer spec.tokenizer_rules
    mode.getNextLineIndent = (state, line, tab) ->
      spec.next_line_indent line
    session.setMode mode

    editor.setShowPrintMargin spec.wrapmode
    session.setUseWrapMode spec.wrapmode
    session.setWrapLimitRange null, spec.wraplimit
    editor.setPrintMarginColumn spec.wraplimit
    renderer.setHScrollBarAlwaysVisible false

    session.on 'change', -> spec.on_document_change() unless spec.readonly
    editor.getSelection().on 'changeCursor', -> spec.on_cursor_change()

  add_command: (spec) ->
    canon.addCommand
      name: spec.name
      exec: (env, args, request) -> spec.exec()
      bindKey:
        win: spec.key_win or null
        mac: spec.key_mac or null
        sender: 'editor'

  add_marker: (spec) ->
    range = new Range spec.start_row, spec.start_column,
                      spec.end_row, spec.end_column
    renderer = (html, range, left, top, config) ->
      column = if range.start.row == range.end.row then range.start.column else 0
      html.push spec.on_render
        left: Math.round column * config.characterWidth
        top: (range.start.row - config.firstRowScreen) * config.lineHeight
        bottom: (range.end.row - config.firstRowScreen + 1) * config.lineHeight
        screen_height: config.height
        screen_width: config.width
        container_height: config.minHeight
    session.addMarker range, spec.klass, renderer, true

  cursor_coordinates: ->
    pos = editor.getCursorPosition()
    screen = editor.renderer.textToScreenCoordinates pos.row, pos.column
    x: Math.round screen.pageX
    y: Math.round screen.pageY + editor.renderer.lineHeight / 2

  cursor_position: -> editor.getCursorPosition()

  focus: -> editor.focus()

  get_length: -> session.getLength()

  get_line: (row) -> session.getLine(row)

  get_selection: ->
    range = editor.getSelection().getRange()
    start: pos_to_offset range.start
    end: pos_to_offset range.end

  get_tokens: (row) ->
    tokens = session.getTokens(row, row)[0]
    result = tokens.tokens
    result.state = tokens.state;
    result

  get_value: -> session.getValue()

  indent: -> editor.indent()

  insert: (text) -> editor.insert text

  navigate_line_end: -> editor.navigateLineEnd()

  navigate_line_start: -> editor.navigateLineStart()

  navigate: (position) -> editor.navigateTo position.row, position.column

  outdent: -> editor.blockOutdent()

  remove_marker: (marker_id) -> session.removeMarker marker_id

  replace: (start, end, text) ->
    range = Range.fromPoints offset_to_pos(start), offset_to_pos(end)
    session.replace range, text

  replace_lines: (start, end, lines) ->
    doc = session.getDocument()
    doc_length = end - start + 1;
    min_length = Math.min doc_length, lines.length

    for i in [0...min_length]
      if doc.getLine(start + i) != lines[i]
        doc.removeInLine start + i, 0, Infinity
        doc.insertInLine {row: start + i, column: 0}, lines[i]

    if doc_length > lines.length
      doc.removeLines start + lines.length, end
    if doc_length < lines.length
      doc.insertLines end + 1, lines.slice doc_length

  resize: -> editor.resize()

  set_keyboard_states: (states) ->
    editor.setKeyboardHandler new StateHandler states

  set_selection: (start, end) ->
    range = Range.fromPoints offset_to_pos(start), offset_to_pos(end)
    editor.getSelection().setSelectionRange range

  set_value: (value) -> session.setValue value

  set_wrap_mode: (value) ->
    editor.setShowPrintMargin value
    session.setUseWrapMode value

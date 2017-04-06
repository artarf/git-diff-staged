{CompositeDisposable} = require 'atom'
toggleStaged = GitDiffStagedView = repositoryForPath = null
{diffAtLine, previousDiff, nextDiff} = require "./utils"
{Point} = require "atom"

getGitPath = ->
  git = atom.config.get("git-diff-staged.gitPath")
  return git if git isnt module.exports.config.gitPath.default
  atom.config.get("git-plus.general.gitPath") ? 'git'

module.exports =
  vimMode: null
  subscriptions: null

  config:
    ignorePrecedingDeletion:
      description: '''When selection starts at the first line of a modification
      (not including the preceding line), the **deleted lines are not added**
      to the index if this setting is enabled.'''
      type: 'boolean'
      default: false
    gitPath:
      description: "If git is not in your PATH, specify where the executable is"
      type: "string"
      default: "use setting from git-plus package"

  activate: ->
    @subscriptions = new CompositeDisposable()
    GitDiffStagedView = require './git-diff-staged-view'
    {repositoryForPath} = require './helpers'
    {toggleStaged} = require './utils'
    @subscriptions.add atom.workspace.observeTextEditors (editor)=>
      @subscriptions.add new GitDiffStagedView(editor)
    @subscriptions.add atom.commands.add 'atom-text-editor', 'git-diff-staged:toggle-selected', ->
      editor = atom.workspace.getActiveTextEditor()
      toggleLines editor, getLines editor.getSelectedBufferRange()
    @subscriptions.add atom.commands.add 'atom-text-editor', 'git-diff-staged:toggle-hunk-at-cursor', ->
      editor = atom.workspace.getActiveTextEditor()
      toggleLines editor, getHunkLines editor
  deactivate: -> @subscriptions.dispose()

  consumeVimModePlus: (@vimMode)->
    {Base} = @vimMode
    Operator = Base.getClass "Operator"
    class ToggleStaged extends Operator
      @commandPrefix: 'git-diff-staged'
      @registerCommand()
      mutateSelection: (selection)->
        toggleLines selection.editor, getLines selection.getBufferRange()

    TextObject = Base.getClass "TextObject"
    class Hunk extends TextObject
      @commandPrefix: 'git-diff-staged'
      @deriveInnerAndA()
      wise: 'linewise'
      getRange: (selection)->
        editor = atom.workspace.getActiveTextEditor()
        diffs = getDiffs editor
        return unless diffs?.length
        [start, end] = _getHunkLines editor, pos = @getCursorPositionForSelection(selection)
        return if start is -1
        @getBufferRangeForRowRange [start-1, end-1]
    Base.getClass("InnerHunk").registerCommand()
    Base.getClass("AHunk").registerCommand()

    Motion = Base.getClass "Motion"
    class MoveToNextHunk extends Motion
      @commandPrefix: 'git-diff-staged'
      @registerCommand()
      jump: true
      direction: 'next'
      getPoint: (fromPoint)->
        editor = atom.workspace.getActiveTextEditor()
        diffs = getDiffs editor
        return unless diffs?.length
        row = fromPoint.row + 1
        if @direction is 'next'
          d = nextDiff diffs, row
          new Point d.newStart - 1, 0
        else
          d = previousDiff diffs, row
          new Point d.newStart - 1, 0

      moveCursor: (cursor)->
        @moveCursorCountTimes cursor, =>
          @setBufferPositionSafely(cursor, @getPoint(cursor.getBufferPosition()))

    class MoveToPreviousHunk extends MoveToNextHunk
      @registerCommand()
      direction: 'previous'

getLines = ({start, end})-> [start.row + 1, end.row + (end.column > 0)]

getHunkLines = (editor)-> _getHunkLines(editor, editor.getCursorBufferPosition())

getDiffs = (editor)-> repositoryForPath(editor.getPath()).getLineDiffs(editor.getPath(), editor.getText())

_getHunkLines = (editor, {row})->
  return [-1, -1] unless d = diffAtLine getDiffs(editor), row
  return [d.newStart, d.newStart + d.newLines - (d.newLines isnt 0)]

toggleLines = (editor, [first, last])->
  file = editor.getPath()
  return unless repo = repositoryForPath(file)
  text = editor.getText()
  file = repo.relativize file
  options =
    ignorePrecedingDeletion: atom.config.get 'git-diff-staged.ignorePrecedingDeletion'
    gitExecutable: getGitPath()
  toggleStaged(repo.getRepo(file), file, text, first, last, options).then (result)->
    return console.warn 'nothing to do' unless result?
    return console.error result.err.join '' if result.code isnt 0
    editorElement = atom.views.getView(editor)
    atom.commands.dispatch(editorElement, 'git-diff-staged:update-diffs')

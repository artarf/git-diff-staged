{CompositeDisposable} = require 'atom'
toggleStaged = GitDiffStagedView = repositoryForPath = null
repositoryForEditor = null
{diffAtLine, previousDiff, nextDiff} = require "./utils"
{Point} = require "atom"

getGitPath = ->
  git = atom.config.get("git-diff-staged.gitPath")
  return git if git isnt module.exports.config.gitPath.default
  atom.config.get("git-plus.general.gitPath") ? 'git'

module.exports =
  vimMode: null
  subscriptions: null
  views: new WeakMap

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
    repositoryForEditor = (editor)=> @views.get(editor)?.getRepositorySync()
    {toggleStaged} = require './utils'
    @subscriptions.add atom.workspace.observeTextEditors (editor)=>
      @views.set editor, view = new GitDiffStagedView(editor, this)
      @subscriptions.add view
    @subscriptions.add atom.commands.add 'atom-text-editor.git', 'git-diff-staged:toggle-selected', ->
      editor = atom.workspace.getActiveTextEditor()
      toggleLines editor, getLines editor.getSelectedBufferRange()
    @subscriptions.add atom.commands.add 'atom-text-editor.git', 'git-diff-staged:toggle-hunk-at-cursor', ->
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
        return

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

getDiffs = (editor)-> repositoryForEditor(editor)?.getLineDiffs(editor.getPath(), editor.getText())

_getHunkLines = (editor, {row})->
  return [-1, -1] unless d = getDiffs(editor)
  return [-1, -1] unless d = diffAtLine d, row
  return [d.newStart, d.newStart + d.newLines - (d.newLines isnt 0)]

toggleLines = (editor, [first, last])->
  file = editor.getPath()
  return unless repo = repositoryForEditor(editor)
  text = editor.getText()
  file = repo.relativize file
  options =
    ignorePrecedingDeletion: atom.config.get 'git-diff-staged.ignorePrecedingDeletion'
    gitExecutable: getGitPath()
  toggleStaged(repo.getRepo(file), file, text, first, last, options)
  .then (result)->
    return console.warn 'nothing to do' unless result?
    return console.error result.err.join '' if result.code isnt 0
  .catch (err)->
    console.error err.stack
    console.log err.details.cmd
    console.log err.details.out
    console.error err.details.err
    console.error err.details.patch
    console.log err
    atom.notifications.addError(err.message)

{CompositeDisposable} = require 'atom'
toggleStaged = GitDiffStagedView = repositoryForPath = null

getGitPath = ->
  atom.config.get("git-diff-staged.gitPath") ? atom.config.get("git-plus.general.gitPath") ? 'git'

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
      default: "git"

  activate: ->
    @subscriptions = new CompositeDisposable()
    GitDiffStagedView = require './git-diff-staged-view'
    {repositoryForPath} = require './helpers'
    {toggleStaged} = require './utils'
    @subscriptions.add atom.workspace.observeTextEditors (editor)->
      new GitDiffStagedView(editor)
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

getLines = ({start, end})-> [start.row + 1, end.row + (end.column > 0)]

getHunkLines = (editor)->
  file = editor.getPath()
  return unless repo = repositoryForPath(file)
  {row} = editor.getCursorBufferPosition()
  for {newStart, newLines} in repo.getLineDiffs(file, editor.getText()) when -1 < row - newStart < newLines
    return [newStart, newStart + newLines]
  [-1, -1]

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
    # fake edit to make sure git gutter is updated
    pos = editor.getCursorBufferPosition()
    editor.setTextInBufferRange [pos, pos], ''

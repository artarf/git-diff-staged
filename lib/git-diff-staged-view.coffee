{CompositeDisposable} = require 'atom'
{repositoryForPath} = require './helpers'

module.exports =
class GitDiffStagedView
  constructor: (editor)->
    @reset()
    @editor = editor

    @subscriptions.add @editor.onDidChange(@scheduleUpdate)
    @subscriptions.add @editor.onDidChangePath(@scheduleUpdate)

    @subscribeToRepository()
    @subscriptions.add atom.project.onDidChangePaths @subscribeToRepository

    @subscriptions.add @editor.onDidDestroy @dispose

    editorElement = atom.views.getView(editor)
    @subscriptions.add atom.commands.add editorElement, 'git-diff-staged:update-diffs', @scheduleUpdate

    @scheduleUpdate(100)

  reset: ->
    @subscriptions = new CompositeDisposable()
    @decorations = {}
    @markers = []
    @timeoutId = @repository = @editor = null

  dispose: =>
    @cancelUpdate()
    @removeDecorations()
    @subscriptions?.dispose()
    @reset()

  subscribeToRepository: =>
    if @repository = repositoryForPath(@editor.getPath())
      @subscriptions.add @repository.onDidChangeStatuses @scheduleUpdate
      @subscriptions.add @repository.onDidChangeStatus (changedPath) =>
        @scheduleUpdate() if changedPath is @editor.getPath()

  cancelUpdate: ->
    clearTimeout(@timeoutId)

  scheduleUpdate: (timeout = 50)=>
    @cancelUpdate()
    @timeoutId = setTimeout(@updateDiffs, timeout)

  updateDiffs: =>
    return unless @editor

    @removeDecorations()
    if @repository and path = @editor?.getPath()
      text = @editor.getText()
      repo = @repository.getRepo(path)
      file = repo.relativize(path)
      if diffs = repo.getLineDiffs(file, text, useIndex: true)
        indexText = repo.getIndexBlob(file)
        indexToHeadDiffs = repo.getLineDiffs(file, indexText, useIndex: false)
        @addDecorations(diffs, indexToHeadDiffs)

  addDecorations: (diffs, indexToHeadDiffs)->
    indexToHead = []
    for d in indexToHeadDiffs or []
      end = d.newLines or 1
      indexToHead[i + d.newStart] = d for i in [0...end]
    for {oldStart, newStart, oldLines, newLines} in diffs
      startRow = newStart - 1
      endRow = newStart + newLines - 1
      if oldLines is 0 and newLines > 0
        if indexToHead[oldStart]?.newLines is 0
          @markRange(startRow - 1, startRow, 'git-index-partial')
        @markRange(startRow, endRow, 'not-staged git-index-added')
      else if newLines is 0 and oldLines > 0
        @markRange(startRow, startRow+1, 'not-staged git-index-removed')
      else
        @markRange(startRow, endRow, 'not-staged git-index-modified')
    return

  removeDecorations: ->
    marker.destroy() for marker in @markers
    @markers = []

  markRange: (startRow, endRow, klass)->
    marker = @editor.markBufferRange([[startRow, 0], [endRow, 0]], invalidate: 'never')
    @editor.decorateMarker(marker, type: 'line-number', class: klass)
    @markers.push(marker)

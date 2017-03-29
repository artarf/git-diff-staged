{CompositeDisposable} = require 'atom'
{repositoryForPath} = require './helpers'

getDiffs = (repository, path, text)->
  repo = repository.getRepo(path)
  repo.getLineDiffs(repo.relativize(path), text, useIndex: true)

module.exports =
class GitDiffStagedView
  constructor: (@editor)->
    @subscriptions = new CompositeDisposable()
    @decorations = {}
    @markers = []

    @subscriptions.add(@editor.onDidStopChanging(@updateDiffs))
    @subscriptions.add(@editor.onDidChangePath(@updateDiffs))

    @subscribeToRepository()
    @subscriptions.add atom.project.onDidChangePaths => @subscribeToRepository()

    @subscriptions.add @editor.onDidDestroy =>
      @cancelUpdate()
      @removeDecorations()
      @subscriptions.dispose()

    @scheduleUpdate()

  subscribeToRepository: ->
    if @repository = repositoryForPath(@editor.getPath())
      @subscriptions.add @repository.onDidChangeStatuses =>
        @scheduleUpdate()
      @subscriptions.add @repository.onDidChangeStatus (changedPath) =>
        @scheduleUpdate() if changedPath is @editor.getPath()

  cancelUpdate: ->
    clearImmediate(@immediateId)

  scheduleUpdate: ->
    @cancelUpdate()
    @immediateId = setImmediate(@updateDiffs)

  updateDiffs: =>
    return if @editor.isDestroyed()

    @removeDecorations()
    if @repository and path = @editor?.getPath()
      text = @editor.getText()
      if diffs = getDiffs @repository, path, text
        @addDecorations(diffs)

  addDecorations: (diffs)->
    for {newStart, oldLines, newLines} in diffs
      startRow = newStart - 1
      endRow = newStart + newLines - 1
      if oldLines is 0 and newLines > 0
        @markRange(startRow, endRow, 'git-index-added')
      else if newLines is 0 and oldLines > 0
        @markRange(startRow, startRow+1, 'git-index-removed')
      else
        @markRange(startRow, endRow, 'git-index-modified')
    return

  removeDecorations: ->
    marker.destroy() for marker in @markers
    @markers = []

  markRange: (startRow, endRow, klass)->
    marker = @editor.markBufferRange([[startRow, 0], [endRow, 0]], invalidate: 'never')
    @editor.decorateMarker(marker, type: 'line-number', class: "not-staged " + klass)
    @markers.push(marker)

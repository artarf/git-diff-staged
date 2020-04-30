{watchPath} = require('atom')
{join} = require 'path'
{Directory, CompositeDisposable} = require 'atom'
{repositoryForPath} = require './helpers'

module.exports =
class GitDiffStagedView
  constructor: (editor)->
    @reset()
    @editor = editor

    @subscriptions.add @editor.onDidChange(@scheduleUpdate)
    @subscriptions.add @editor.onDidChangePath(@subscribeToRepository)

    @subscribeToRepository()
    @subscriptions.add atom.project.onDidChangePaths @subscribeToRepository

    @subscriptions.add @editor.onDidDestroy @dispose

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

  getRepositorySync: -> @repository
  subscribeToRepository: =>
    @repository = null
    return unless dir = @editor.getDirectoryPath()
    atom.project.repositoryForDirectory(new Directory dir).then (@repository)=>
      return unless @repository
      @editor.element.classList.add 'git'
      @relativePath = @repository.relativize(@editor.getPath())
      # track the pathStatus to avoid unnecessary updates
      @status = @repository.getPathStatus(@relativePath)
      @subscriptions.add @repository.onDidChangeStatuses =>
        current = @repository.getPathStatus(@relativePath)
        if @status isnt current
          @status = current
          @scheduleUpdate()
      @subscriptions.add @repository.onDidChangeStatus ({path, pathStatus})=>
        return if path isnt @relativePath
        @status = pathStatus
        @scheduleUpdate()
      @scheduleUpdate()
      @addIndexWatch()

  addIndexWatch: ->
    return unless @repository
    indexFile = join(@repository.getPath(), 'index.lock')
    promise = watchPath @repository.getPath(), {}, (events)=>
      for e in events when e.path is indexFile
        @scheduleUpdate()
        break
      return
    promise.then (disposable)=>
      @subscriptions.add disposable

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

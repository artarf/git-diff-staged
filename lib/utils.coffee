cp = require 'child_process'

# Moves changes to index in given line range, or if there is no
# changes, reverts them. Does nothing if there is nothing
# to revert either.
#
# repo   is a git repository object which is returned by
#        atom/git-utils open() function
# file   is relative path to a file within repository
# first  is 1 based index of the starting line
# last   is **inclusive** 1 based index of the last line
# options
#   ignorePrecedingDeletion (false):
#      When selection starts at the first line of a modification
#      (not including the preceding line), the **deleted lines are not added**
#      to the index if this option is enabled.
#   gitExecutable (git):
#      path to git executable as needed by nodejs child_process.spawn()
toggleStaged = (repo, file, text, first, last, options = {})->
  diffs = repo.getLineDiffDetails(file, text, useIndex: true)
  unless patch = getPatch(repo, file, first, last, diffs, options)
    patch = getReversePatch(repo, file, first, last, diffs, options)
  return Promise.resolve() unless patch
  gitApplyPatchToIndex patch, repo.getWorkingDirectory(), options.gitExecutable

getPatch = (repo, file, first, last, indexDiffs, options)->
  hunks = getHunks(indexDiffs, first, last, options)
  if hunks.length
    indexText = applyHunks hunks, repo.getIndexBlob(file)
    diffs = repo.getLineDiffDetails(file, indexText, useIndex: true)
    hunks = getHunks(diffs, 0, 9999999, options)
    return patch = createPatch hunks, file if hunks.length

offset = (indexDiffs, index)->
  _offset = 0
  for d in indexDiffs
    break if d.newStart > index or d.newLineNumber > index
    if ~d.newLineNumber then _offset-- else _offset++
  _offset

getReversePatch = (repo, file, first, last, indexDiffs, options)->
  _offset = offset indexDiffs, first
  first += _offset
  # in reversing we know that there is no differences between first and last
  # -> we can use the same offset
  last += _offset
  indexText = repo.getIndexBlob(file)
  return unless diffs = repo.getLineDiffDetails(file, indexText, useIndex: false)
  hunks = getHunks(diffs, first, last, options)
  return unless hunks.length
  indexText = revertHunks hunks, indexText
  diffs = repo.getLineDiffDetails(file, indexText, useIndex: true)
  hunks = getHunks(diffs, 0, 9999999, options)
  createPatch hunks, file, true

revertHunks = (hunks, text)->
  return text unless hunks.length
  _lines = text.split '\n'
  for {oldStart, newStart, oldlines, lines} in hunks by -1
    _lines.splice newStart-1, lines.length, oldlines...
  _lines.join '\n'

isDiffInRange = (first, last, ignorePrecedingDeletion)-> (d)->
  return false unless d?
  if ~d.newLineNumber
    first <= d.newLineNumber <= last
  else if d.newLines is 0
    # plain deletion, newStart points to existing line before deletion
    first = 0 if first is 1
    first <= d.newStart <= last
  else
    # modification, newStart points to first +line
    if ignorePrecedingDeletion
      first < d.newStart <= last+1
    else
      first <= d.newStart <= last+1

notNull = (x)-> x?

processHunk = ({lines, newStart, oldlines, oldStart})->
  # fix inconsistencies in start positions (odd behavior in gitDiffDetails)
  newStart++ if lines.length is 0
  oldStart++ if oldlines.length is 0

  newStart += i if ~i = lines.findIndex(notNull)
  lines = lines.filter notNull
  oldlen = oldlines.length
  oldlines = oldlines.filter notNull
  oldStart += oldlen - oldlines.length
  {lines, newStart, oldlines, oldStart}

getHunks = (diffs, first, last, options)->
  {ignorePrecedingDeletion} = options ? {}
  hunks = []
  diffs = diffs.filter isDiffInRange(first, last, ignorePrecedingDeletion)
  current = 0
  for {newStart, oldStart, newLines, oldLines, newLineNumber, oldLineNumber, line}, i in diffs
    hunk = hunks[current] ?= {lines: new Array(newLines), oldlines: new Array(oldLines), oldStart, newStart}
    line = line.slice(0, -1)
    if ~newLineNumber
      hunk.lines[newLineNumber - newStart] = line
    else
      hunk.oldlines[oldLineNumber - oldStart] = line
    current++ if oldStart isnt diffs[i+1]?.oldStart
  hunks.map processHunk

applyHunks = (hunks, text)->
  return text unless hunks.length
  _lines = text.split '\n'
  for {oldStart, newStart, oldlines, lines} in hunks by -1
    _lines.splice oldStart-1, oldlines.length, lines...
  _lines.join '\n'

createPatch = (hunks, file)->
  return unless hunks.length
  patch = "diff --git a/#{file} b/#{file}\n"
  patch += "--- a/#{file}\n+++ b/#{file}\n"
  for {oldStart, newStart, oldlines, lines} in hunks
    patch += "@@ -#{oldStart},#{oldlines.length} +#{newStart},#{lines.length} @@\n"
    patch += '-' + l + '\n' for l in oldlines
    patch += '+' + l + '\n' for l in lines
  patch

gitApplyPatchToIndex = (patch, dir, git = 'git')->
  new Promise (resolve, reject)->
    options = ['apply', '--cached', '-v', '--unidiff-zero', '-']
    child = cp.spawn git, options, cwd: dir
    child.stdin.setEncoding('utf-8')
    ret = err: [], out: [], patch: patch, cmd: git + ' ' + options.join ' '
    child.stdout.on 'data', (chunk)-> ret.out.push ''+chunk
    child.stderr.on 'data', (chunk)-> ret.err.push ''+chunk
    child.on 'exit', (code, signal)->
      if code
        err = new Error "git execution returned " + code
        err.details = Object.assign ret, {code, signal}
        reject err
        # If you are listening to both the 'exit' and 'error' events,
        # it is important to guard against accidentally invoking handler
        # functions multiple times.
        reject = ->
      else
        resolve Object.assign ret, {code, signal}
    child.on 'error', (err)->
      err.details = ret
      reject err
      reject = ->
    child.stdin.write patch
    child.stdin.end()

nextDiffIndex = (diffs, line)-> diffs.findIndex (d)-> d.newStart > line
nextDiff = (diffs, line)-> diffs[nextDiffIndex diffs, line] ? diffs[0]
previousDiff = (diffs, line)->
  i = nextDiffIndex(diffs, line - 1)
  if ~i then i-- else i = diffs.length - 1
  diffs[i] ? diffs[diffs.length - 1]
diffAtLine = (diffs, line)-> diffs.find (d)-> -1 <= line - d.newStart < d.newLines + (line is 0)

module.exports = {
  processHunk
  gitApplyPatchToIndex
  toggleStaged
  getHunks
  applyHunks
  createPatch
  getPatch
  getReversePatch
  isDiffInRange
  nextDiff
  previousDiff
  diffAtLine
}

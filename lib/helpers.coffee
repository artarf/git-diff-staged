repositoryForPath = (goalPath)->
  for directory, i in atom.project.getDirectories()
    if goalPath is directory.getPath() or directory.contains(goalPath)
      return atom.project.getRepositories()[i]
  false

module.exports = {
  repositoryForPath
}

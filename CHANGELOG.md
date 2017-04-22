## 0.4.0 - Enhance detection of index changes + fix bugs
- Improve index change detection 
  - Let also other git packages know when index is changed, because
    atom/git-utils Repository does not always detect index changes.
    For example tree view does not update when doing
- Target commands only to git repository files by adding
  `git` class to `atom-text-editor`
- Fix bug in some special text editors which do not use actual files 
    fs.watch() for directory is sometimes very slow. using
    file directly significantly reduced delay overall.
- Fix: inner-hunk selects modification when on next line 
- Update readme 

## 0.3.0 - Reliable detection of index changes
- Staged indicators were not always updated when git-plus was
  used to add files to index

## 0.2.0 - Add some vim-mode-plus stuff
- plus some minor fixes

## 0.1.1 - Bug fixes
- fix toggle-hunk-at-cursor
- fix gutter partial modification indicator
- enhance readme

## 0.1.0 - First Release

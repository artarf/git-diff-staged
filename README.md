# Git Diff Staged package

Marks staged lines in the gutter and allows moving partial hunks back and forth.

## Installation

```
apm install git-diff-staged
```

## Styles

This plugin extends styles in core package `atom/git-diff`, which is enabled by default.
Visual distinction is implemented only with no icons (`Show Icons In Editor Gutter` disabled), 
i.e. with the left borders and small triangles.

Staged changes are indicated with dotted left borders. Staged deletions are marked by
changing the color of the small triangle.

Inconsistencies between index and current file are marked with white color and dotted thinner
border. This usually is a situation that should be corrected by toggling the staged state.
These situations can be done by making a change, staging it and then undoing the change.

## Commands

- `git-diff-staged:toggle-selected`

  Adds all changed lines within selection to index, unless
  all changed lines already are in index, in which case
  they are removed from index. If selection contains no changes,
  staged or not, nothing is done.
  
- `git-diff-staged:toggle-hunk-at-cursor`

  Similar to `toggle-selected`, instead of selected lines this
  variation uses the hunk surrounding cursor, if there are changes
  at that position.
  
Also adds a vim-mode-plus Operation to toggle staging status for a movement:

- `git-diff-staged:toggle-staged`

Note that you don't need to save the file to modify the index.

## Keys

No default keymap provided.

Example keymap:
```
'atom-workspace atom-text-editor':
  'ctrl-alt-shift-cmd-s': 'git-diff-staged:toggle-selected'
  'ctrl-alt-shift-cmd-h': 'git-diff-staged:toggle-hunk-at-cursor'
```

Example keymap (vmp):
```
'atom-workspace atom-text-editor.vim-mode-plus:not(.insert-mode)':
  's i f': 'git-diff-staged:toggle-staged'
```

## Configuration

You may customize the git command path with `git-diff-staged.gitPath`.
If you are using `git-plus` package, it's configuration
`git-plus.general.gitPath` is used (unless you want to override it).

By default preceding deletions are included when the first line to staged is
a modification. You can prevent that with `git-diff-staged.ignorePrecedingDeletion`.

## Contributing

I'd like to keep this package as simple as possible so new features are
critically observed. Creating an issue before creating a pull request is
good practice.

Particularly help with styles is greatly appreciated.
I don't have the necessary skills to get good defaults
that work with various themes.

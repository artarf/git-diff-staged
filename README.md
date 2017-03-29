# Git Diff Staged package

Marks staged lines in the gutter and allows moving partial hunks back and forth.

Adds vim-mode-plus command to toggle staging status for a movement.

Example keymap (vmp):
```
'atom-workspace atom-text-editor.vim-mode-plus:not(.insert-mode)':
  's i f': 'git-diff-staged:toggle-staged'
```

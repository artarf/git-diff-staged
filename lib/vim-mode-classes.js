"use babel"

import {diffAtLine, previousDiff, nextDiff} from "./utils"
import {Point} from "atom"
const COMMANDPREFIX = 'git-diff-staged'

module.exports = function(_getHunkLines, getLines, toggleLines, getDiffs, Base) {

  const Operator = Base.getClass("Operator")

  class ToggleStaged extends Operator {
      static commandPrefix = COMMANDPREFIX
      mutateSelection(selection) {
        toggleLines(selection.editor, getLines(selection.getBufferRange()))
      }

  }

  ToggleStaged.registerCommand()

  const TextObject = Base.getClass("TextObject")

  class Hunk extends TextObject {
      static commandPrefix = COMMANDPREFIX
      wise = 'linewise'
      getRange(selection) {
        var diffs, end, pos, start
        const editor = atom.workspace.getActiveTextEditor()
        diffs = getDiffs(editor)
        if (!(diffs != null ? diffs.length : void 0)) {
          return
        }
        [start, end] = _getHunkLines(editor, pos = this.getCursorPositionForSelection(selection))
        if (start > -1) {
          return this.getBufferRangeForRowRange([start - 1, end - 1])
        }
      }
  }

  Hunk.register(false, true)
  Base.getClass("InnerHunk").registerCommand()
  Base.getClass("AHunk").registerCommand()

  const Motion = Base.getClass("Motion")

  class MoveToNextHunk extends Motion {
      static commandPrefix = COMMANDPREFIX

      jump = true
      direction = 'next'

      getPoint(fromPoint) {
        var d, diffs, row
        const editor = atom.workspace.getActiveTextEditor()
        diffs = getDiffs(editor)
        if (!(diffs != null ? diffs.length : void 0)) {
          return
        }
        row = fromPoint.row + 1
        if (this.direction === 'next') {
          d = nextDiff(diffs, row)
          return new Point(d.newStart - 1, 0)
        } else {
          d = previousDiff(diffs, row)
          return new Point(d.newStart - 1, 0)
        }
      }

      moveCursor(cursor) {
        return this.moveCursorCountTimes(cursor, () => {
          const point = this.getPoint(cursor.getBufferPosition())
          if (point) cursor.setScreenPosition(point)
        })
      }

  }

  MoveToNextHunk.registerCommand()

  class MoveToPreviousHunk extends MoveToNextHunk {
    direction = 'previous'
  }

  MoveToPreviousHunk.registerCommand()

}

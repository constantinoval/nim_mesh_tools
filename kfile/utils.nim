import strformat
import strutils
import std/terminal
import std/os

type
    Matrix3* = array[1..3, array[1..3, float]]

proc `[]`(m: Matrix3, i, j: int): float = 
    result = m[i][j]

func determinant*(m: Matrix3): float =
    result += m[1, 1]*m[2, 2]*m[3, 3]
    result += m[1, 2]*m[2, 3]*m[3, 1]
    result += m[2, 1]*m[3, 2]*m[1, 3]
    result -= m[1, 3]*m[2, 2]*m[3, 1]
    result -= m[1, 1]*m[2, 3]*m[3, 2]
    result -= m[3, 3]*m[2, 1]*m[1, 2]

type
    PeaceToProceed* = tuple
        start: int
        length: int

proc splitSeq*(length: int, num: int): seq[PeaceToProceed] = 
    var num = min(num, length)
    var count = length
    if num < 2:
        result = @[(start: 0, length: length)]
        return
    # var
    #     stride = length div num
    #     extra = length mod num
    #     count = length
    result = newSeqOfCap[PeaceToProceed](num)
    # if extra > 0:
    #     inc(stride)
    for i in 0 ..< num:
        result.add((start: 0, length: 0))
    block fill:
        while true:
            for i in 0 ..< num:
                inc(result[i].length)
                dec(count)
                if count == 0:
                    break fill
    for i in 1 ..< num:
        for j in 0 ..< i:
            result[i].start += result[j].length

proc progress*(cur, total: int, scaleLength: int=20, text: string="Progress=", symbol: string="-#") =
    var
        prog: int
        result: string
    if total!=0:
        prog=(100.0*cur.float/total.float).int
    else:
        prog=100
    result = fmt"{text}{prog:4d}% "
    let numD = ((prog*scaleLength).float/100.0).int
    result.add("[")
    result.add(repeat(symbol[1], numD))
    result.add(repeat(symbol[0], scaleLength-numD))
    result.add("]")
    result.add(fmt" Total={total:10d}, current={cur:10d}")
    cursorUp(1)
    eraseLine()
    echo result
    

when isMainModule:
#   echo splitSeq(10, 4)
#   let a = 1
#   echo as
    for i in 1..10:
        sleep(100)
        progress(i.toFloat, 10.0)

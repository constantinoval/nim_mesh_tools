import point
import strutils
import std/strformat
import std/parseutils
import utils

type
    FEnode* = ref object of Point
        n* : int

proc `$`*(n: FEnode): string = 
    "n=" & $n.n & " (" & $n.x &
    ", " & $n.y & ", " & $n.z & ")"

proc fromStringFast*(l: string): FENode =
    result = new(FEnode)
    var p = 0
    p += l.skipUntil({'0'..'9'}, p)
    p += parseutils.parseInt(l, result.n, p)
    p += l.skipUntil({'0'..'9', '-'}, p)
    p += parseutils.parseFloat(l, result.x, p)
    p += l.skipUntil({'0'..'9', '-'}, p)
    p += parseutils.parseFloat(l, result.y, p)
    p += l.skipUntil({'0'..'9', '-'}, p)
    p += parseutils.parseFloat(l, result.z, p)


proc formattedLine*(nd: FEnode): string = 
    ($nd.n).align(8) &
    formatFloat(nd.x, format=ffScientific, precision=7).align(16) &
    formatFloat(nd.y, format=ffScientific, precision=7).align(16) &
    formatFloat(nd.z, format=ffScientific, precision=7).align(16)

proc volume4nodes*(nodes: openArray[FEnode]): float =
    var matrix: Matrix3
    matrix[1] = (nodes[1]-nodes[0]).coords
    matrix[2] = (nodes[2]-nodes[0]).coords
    matrix[3] = (nodes[3]-nodes[0]).coords
    result = abs(matrix.determinant/6.0)

when isMainModule:
    # let n1 = FEnode(x: 0, y: 0, z: 0)
    # let n2 = FEnode(x: 1, y: 0, z: 0)
    # let n3 = FEnode(x: 0, y: 1, z: 0)
    # let n4 = FEnode(x: 0, y: 0, z: 1)
    # echo volume4nodes(@[n1, n2, n3, n4])
    var n = fromStringFast("1546, 0, 0.460540062649227, -1.92118277136802")
    echo n
    echo n.formattedLine

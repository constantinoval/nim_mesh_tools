import point
import strutils
import std/strformat
import std/parseutils
import utils

type
    FEnode* = object of Point
        n* : int

proc `$`*(n: FEnode): string = 
    "n=" & $n.n & " (" & $n.x &
    ", " & $n.y & ", " & $n.z & ")"

proc fromStringFast*(l: string): FENode =
    var p = 0
    p += l.skipUntil({'0'..'9'}, p)
    p += parseutils.parseInt(l, result.n, p)
    p += l.skipUntil({'0'..'9'}, p)
    p += parseutils.parseFloat(l, result.x, p)
    p += l.skipUntil({'0'..'9'}, p)
    p += parseutils.parseFloat(l, result.y, p)
    p += l.skipUntil({'0'..'9'}, p)
    p += parseutils.parseFloat(l, result.z, p)


proc formattedLine*(nd: FEnode): string = 
    let n = nd.n
    let x = nd.x
    let y = nd.y
    let z = nd.z
    result = fmt" {n:>7d} {x:>15e} {y:>15e} {z:>15e}"

proc volume4nodes*(nodes: openArray[FEnode]): float =
    var matrix: Matrix3
    matrix[1] = (nodes[1]-nodes[0]).coords
    matrix[2] = (nodes[2]-nodes[0]).coords
    matrix[3] = (nodes[3]-nodes[0]).coords
    result = abs(matrix.determinant/6.0)

when isMainModule:
    let n1 = FEnode(x: 0, y: 0, z: 0)
    let n2 = FEnode(x: 1, y: 0, z: 0)
    let n3 = FEnode(x: 0, y: 1, z: 0)
    let n4 = FEnode(x: 0, y: 0, z: 1)
    echo volume4nodes(@[n1, n2, n3, n4])

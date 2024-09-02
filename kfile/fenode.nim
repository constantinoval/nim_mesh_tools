import point
import strutils
import std/parseutils
import std/algorithm
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

proc dist*(n1: FEnode, n2: FEnode): float =
    return (n1-n2).len

proc dist2*(n1: FEnode, n2: FEnode): float =
    return (n1.x-n2.x)*(n1.x-n2.x)+
           (n1.y-n2.y)*(n1.y-n2.y)+
           (n1.z-n2.z)*(n1.z-n2.z)

proc sort1d*(nodes: var openArray[FEnode], rounded: int = 0, crds_index: int = 0) =
    proc compare(n1, n2: FEnode): int =
        var
            crds1: array[0..2, float]
            crds2: array[0..2, float]
        if rounded == 0:
            crds1 = n1.coords
            crds2 = n2.coords
        else:
            crds1 = n1.coords_rounded(rounded)
            crds2 = n2.coords_rounded(rounded)
        if crds1[crds_index]>crds2[crds_index]:
            return 1
        elif crds1[crds_index]<crds2[crds_index]:
            return -1
        else:
            return 0
    sort(nodes, compare)

proc sort2d*(nodes: var openArray[FEnode], rounded: int = 0, crds_index: array[0..1, int] = [0, 1]) =
    proc compare(n1, n2: FEnode): int =
        var
            crds1: array[0..2, float]
            crds2: array[0..2, float]
        if rounded == 0:
            crds1 = n1.coords
            crds2 = n2.coords
        else:
            crds1 = n1.coords_rounded(rounded)
            crds2 = n2.coords_rounded(rounded)
        if crds1[crds_index[0]]>crds2[crds_index[0]]:
            return 1
        elif crds1[crds_index[0]]<crds2[crds_index[0]]:
            return -1
        else:
            if crds1[crds_index[1]]>crds2[crds_index[1]]:
                return 1
            elif crds1[crds_index[1]]<crds2[crds_index[1]]:
                return -1
            else:
                return 0
    sort(nodes, compare)

when isMainModule:
    let n1 = FEnode(n: 1, x: 1.0001, y: 5, z: 0)
    let n2 = FEnode(n: 2, x: 1.0006, y: 1, z: 0)
    echo n1.dist(n2)
    # let n3 = FEnode(x: 0, y: 1, z: 0)
    # let n4 = FEnode(x: 0, y: 0, z: 1)
    # echo volume4nodes(@[n1, n2, n3, n4])
    var n = fromStringFast("1546, 0, 0.460540062649227, -1.92118277136802")
    echo n
    echo n.formattedLine
    var a = @[n1, n2] 
    sort1d(a, rounded=2, crds_index=1)
    echo a
    sort2d(a, rounded=2, crds_index=[0, 1])
    echo a

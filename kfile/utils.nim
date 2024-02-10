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
    if num < 2:
        result = @[(start: 0, length: length)]
        return
    var
        stride = length div num
        extra = length mod num
        count = length
    result = newSeqOfCap[PeaceToProceed](num)
    if extra > 0:
        inc(stride)
    for i in 0 ..< num:
        result.add((start: i*stride, length: 0))
    block fill:
        while true:
            for i in 0 ..< num:
                inc(result[i].length)
                dec(count)
                if count == 0:
                    break fill

when isMainModule:
    var
        p1, p2, p3, p4: Point
    p1.fromSeq([0.0, 0.0, 0.0])
    p2.fromSeq([1.0, 0.0, 0.0])
    p3.fromSeq([0.0, 1.0, 0.0])
    p4.fromSeq([0.0, 0.0, -1.0])
    echo volume4points(@[p1, p2, p3, p4])
    const TetraFacesIndexes = [[1, 2, 3], [2, 3, 4]]
    echo TetraFacesIndexes
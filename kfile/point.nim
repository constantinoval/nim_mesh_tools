import math
import utils

# Point object
type
    Point* = ref object of RootObj
        x*, y*, z*: float

# addition of point        
proc `+`*(n1, n2: Point): Point =
    Point(x: n1.x+n2.x, y: n1.y+n2.y, z: n1.z+n2.z)

# float*point
proc `*`*(s: float, p: Point): Point = 
    Point(x: s*p.x, y: s*p.y, z: s*p.z)

# point*float
proc `*`*(p: Point, s: float): Point = 
    `*`(s, p)

# point to string
proc `$`*(n: Point): string = 
    " (" & $n.x &
    ", " & $n.y & ", " & $n.z & ")"

# scalar product of vectors
proc dot*(p1, p2: Point): float = 
    p1.x*p2.x+p1.y*p2.y+p1.z*p2.z

# coords
proc coords*(p: Point): array[3, float] = 
    [p.x, p.y, p.z]

# rounded coords
proc coords_rounded*(p: Point, num_digits: int = 6): array[3, float] =
    return [round(p.x, num_digits), round(p.y, num_digits), round(p.z, num_digits)]

# point from seq
proc fromSeq*[T](p: var Point, crds: openArray[T]) =
    p.x = float(crds[0])
    p.y = float(crds[1])
    p.z = float(crds[2])

# minus sign
proc `-`*(p: Point): Point =
    -1*p

# length of the vector
proc len*(p: Point): float =
    sqrt(p.x^2+p.y^2+p.z^2)

# cross product
proc cross*(p1, p2: Point): Point = 
        let x = p1.y*p2.z-p1.z*p2.y
        let y = p1.z*p2.x-p1.x*p2.z
        let z = p1.x*p2.y-p1.y*p2.x
        Point(x: x, y: y, z: z)

proc `/`*(p: Point, s: float): Point =
    let ss = 1/s
    p*ss

# mixed product
proc mixed*(p1, p2, p3: Point): float =
    (p1.cross(p2)).dot(p3)

# normalized vector
proc normalized*(p: Point): Point =
    p/p.len

# normalize vector so it's length becomes 1
proc normalize*(p: var Point) =
    p.fromSeq(p.normalized.coords)

# difference of the vectors
proc `-`*(p1, p2: Point): Point =
    p1+(-p2)

# angle between two points
proc angle*(p1, p2: Point, direction_vector: Point=Point(x: 0, y: 0, z: 0)): float =
        let p1_u = p1.normalized
        let p2_u = p2.normalized
        result = arccos(p1_u.dot(p2_u))*180/Pi
        if direction_vector.len>0:
            if p1.cross(p2).dot(direction_vector) < 0:
                result = 360-result

#distance between 2 points
proc dist*(p1, p2: Point): float =
    (p1-p2).len

proc volume4points*(points: openArray[Point]): float =
    var matrix: Matrix3
    matrix[1] = (points[1]-points[0]).coords
    matrix[2] = (points[2]-points[0]).coords
    matrix[3] = (points[3]-points[0]).coords
    result = abs(matrix.determinant/6.0)

proc sort1d*(pnts: var openArray[Point]) =
    discard

when isMainModule:
    var p1 = Point(x: 1.554523235235325, y: 0, z: 0)
    var p2 = Point(x: -1, y: 1, z: 0)
    echo p1.coords_rounded(2)
    # echo $(p1+p2)
    # echo($(p1*7))
    # echo(p1.dot(p2))
    # echo(-p1, p1.len)
    # echo(p1.cross(p2))
    # echo(p2.normalized)
    # echo(p2)
    # p2.normalize
    # echo($p2)
    # echo($(p1-p2))
    # echo(p1.angle(p2))
    # var p = Point()
    # p.fromSeq([1,1,1])
    # echo p
    # echo p1.dist(p2)

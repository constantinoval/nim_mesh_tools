import point, math, fenode

type
    Quaternion* = ref object
        data: array[0..3, float]
        R: array[0..2, array[0..2, float]]
        angle*: float
        axis*: Point
        initialised: bool

proc calculateRotationMatrix(q: Quaternion) =
    let w = q.data[0]
    let x = q.data[1]
    let y = q.data[2]
    let z = q.data[3]
    q.R[0][0] = 1-2*y*y-2*z*z
    q.R[0][1] = 2*x*y-2*z*w
    q.R[0][2] = 2*x*z+2*y*w
    q.R[1][0] = 2*x*y+2*z*w
    q.R[1][1] = 1-2*x*x-2*z*z
    q.R[1][2] = 2*y*z-2*x*w
    q.R[2][0] = 2*x*z-2*y*w
    q.R[2][1] = 2*y*z+2*x*w
    q.R[2][2] = 1-2*x*x-2*y*y
    q.initialised = true

proc init(q: Quaternion) = 
    let a2 = q.angle/2.0*Pi/180
    let sina2 = sin(a2)
    q.data[0]=cos(a2)
    let crds = q.axis.coords
    for i in 0..2:
        q.data[i+1]=crds[i]*sina2
    q.calculateRotationMatrix()

proc rotatedPoint*(q: Quaternion, p: Point): Point =
    if not q.initialised:
        q.init
    var rez = @[0.0, 0.0, 0.0]
    let crds = p.coords
    for i in 0..2:
        for j in 0..2:
            rez[i] += q.R[i][j]*crds[j]
    result = Point()
    result.fromSeq(rez)
    return result

proc rotatePoint*(q: Quaternion, p: var Point) =
    if not q.initialised:
        q.init
    var rez: array[3, float] = [0.0, 0.0, 0.0]
    for i in 0..2:
        for j in 0..2:
            rez[i] += q.R[i][j]*p.coords[j]
    p.x = rez[0]
    p.y = rez[1]
    p.z = rez[2]

proc rotateNode*(q: Quaternion, p: var FEnode) =
    if not q.initialised:
        q.init
    var rez: array[3, float] = [0.0, 0.0, 0.0]
    for i in 0..2:
        for j in 0..2:
            rez[i] += q.R[i][j]*p.coords[j]
    p.x = rez[0]
    p.y = rez[1]
    p.z = rez[2]


when isMainModule:
    let q = Quaternion(angle: 45, axis: Point(x: 0, y: 0, z: 1))
    var p: Point = Point(x: 1, y:0, z: 0)
    q.rotatePoint(p)
    echo(p, p.len)

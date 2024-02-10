import math

type
    Quaternion* = ref object
        data: array[0..3, float]
        R: array[0..2, array[0..2, float]]
        angle*: float
        axis*: array[0..2, float]
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
    let crds = q.axis
    for i in 0..2:
        q.data[i+1]=crds[i]*sina2
    q.calculateRotationMatrix()

proc rotatePoint*(q: Quaternion, p: array[0..2, float]): array[0..2, float] =
    if not q.initialised:
        q.init
    for i in 0..2:
        for j in 0..2:
            result[i] += q.R[i][j]*p[j]

when isMainModule:
    let q = Quaternion(angle: 90, axis: [0, 0, 1])
    let p = q.rotatePoint([1.0, 0, 0])
    echo p 

import fenode
import parseutils
import std/[strformat, strutils]
import std/sequtils

const
    HexFacesIdxs = [
        [1, 4, 3, 2],
        [5, 6, 7, 8],
        [2, 3, 7, 6],
        [1, 5, 8, 4],
        [3, 4, 8, 7],
        [1, 2, 6, 5]
        ]
    WedgeFacesIdxs = [
        @[1, 4, 3, 2],
        @[1, 5, 6, 4],
        @[2, 3, 6, 5],
        @[1, 2, 5],
        @[4, 6, 3]
        ]
    TetraFacesIdxs = [
        [3, 2, 1],
        [2, 4, 1],
        [3, 4, 2],
        [1, 4, 3]
        ]


type
    Etype* = enum ## Типы элементов
        Solid
        Shell
        Solid_ortho
    FEelement* = ref object
        n*: int
        nodes_count*: int
        part*: int 
        nds*: array[1..8, int]
        volume*: float
        case etype*: Etype = Solid
            of Solid_ortho:
                a*: array[1..3, float]
                d*: array[1..3, float]
            else:
                discard

func nodes*(e: FEelement): auto =
    e.nds[1..e.nodes_count]

proc `$`*(e: FEelement): string = 
    result = "num=" & $e.n & ", nodes: " & $e.nodes & ", etype: " & $e.etype & ", part: " & $e.part
    if e.etype == Solid_ortho:
        result &= "\nMaterial vector: a=" & $e.a & " d=" & $e.d

proc normalize_nodes*(self: var FEelement) =
    let uniq_nodes = deduplicate(self.nds)
    self.nodes_count = uniq_nodes.len
    self.nds[1..self.nodes_count] = uniq_nodes

proc fromStringFast*(l: string, etype = Etype.Solid): FEelement =
    result = FEelement(etype: etype)
    let N = l.len
    var
        i: int
        nn: int
    i += l.skipUntil({'0'..'9'}, i)
    i += l.parseInt(result.n, i)
    i += l.skipUntil({'0'..'9'}, i)
    i += l.parseInt(result.part, i)
    var j=1
    while i<N:
        i += l.skipUntil({'0'..'9'}, i)
        i += l.parseInt(nn, i)
        result.nds[j]=nn
        inc(j)
    result.nodes_count = j-1
    result.normalize_nodes

proc fromStringFastOrtho*(l: array[3, string]): FEelement =
    result = fromStringFast(l[0], Etype.Solid_ortho)
    var i: int
    i += l[1].skipUntil({'0'..'9', '-'}, i)
    i += l[1].parseFloat(result.a[1], i)   
    i += l[1].skipUntil({'0'..'9', '-'}, i)
    i += l[1].parseFloat(result.a[2], i)   
    i += l[1].skipUntil({'0'..'9', '-'}, i)
    i += l[1].parseFloat(result.a[3], i)   
    i = 0
    i += l[2].skipUntil({'0'..'9', '-'}, i)
    i += l[2].parseFloat(result.d[1], i)   
    i += l[2].skipUntil({'0'..'9', '-'}, i)
    i += l[2].parseFloat(result.d[2], i)   
    i += l[2].skipUntil({'0'..'9', '-'}, i)
    i += l[2].parseFloat(result.d[3], i) 

proc formattedLine*(self: FEelement): string =
    result = ($self.n).align(8) & ($self.part).align(8)
    case self.nodes_count:
        of 8:
            for n in self.nodes:
                result &= ($n).align(8)
        of 4:
            for n in self.nodes:
                result &= ($n).align(8)
            let n = ($self.nodes[^1]).align(8)
            for i in 1..4:
                result &= n
        of 6:
            for n in self.nodes[0..3]:
                result &= ($n).align(8)
            let s1 = ($self.nodes[^2]).align(8)
            result &= s1 & s1
            let s2 = ($self.nodes[^1]).align(8)
            result &= s2 & s2
        else:
            discard
    if self.etype == Solid_ortho:
        result &= "\n" & formatFloat(self.a[1], ffScientific, 7).align(18) &
                         formatFloat(self.a[2], ffScientific, 7).align(18) &
                         formatFloat(self.a[3], ffScientific, 7).align(18) 
        result &= "\n" & formatFloat(self.d[1], ffScientific, 7).align(18) &
                         formatFloat(self.d[2], ffScientific, 7).align(18) &
                         formatFloat(self.d[3], ffScientific, 7).align(18) 

when isMainModule:
    var el = fromStringFast("2067, 4, 1535, 1517, 1482, 1500, 1513, 1513, 1478, 1478")
    echo el.formattedLine


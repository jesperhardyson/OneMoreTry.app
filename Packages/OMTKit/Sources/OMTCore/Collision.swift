/// Vilken yta ett hinder vaxer ur. Allt farligt sitter fast i golv eller tak,
/// aldrig svavande — det haller spelarens fraga binar. Se spec \u{a7}0.
public enum Surface: Sendable {
    case floor, ceiling
}

public struct Obstacle: Sendable {
    public var surface: Surface
    /// Vanstra kanten i varldsenheter.
    public var x: Double
    public var width: Double
    /// Hojd fran sin egen yta och inat i kanalen.
    public var height: Double

    public init(surface: Surface, x: Double, width: Double, height: Double) {
        self.surface = surface
        self.x = x
        self.width = width
        self.height = height
    }

    func box(channelHeight: Double) -> AABB {
        switch surface {
        case .floor:
            AABB(minX: x, maxX: x + width, minY: 0, maxY: height)
        case .ceiling:
            AABB(minX: x, maxX: x + width, minY: channelHeight - height, maxY: channelHeight)
        }
    }
}

/// Ett hinder fast vid en av tubens fyra vaggar. Motsvarar `Obstacle` for
/// kanalen, men indexerar vagg istallet for golv/tak — se spec §3.7. Har
/// ingen egen "hojd": traffzonen ar en fast vinkelbredd runt vaggen, harledd
/// ur `Tuning.angularHalfWidth`, inte ur hindret.
public struct WallObstacle: Sendable {
    public var wall: UInt8
    public var x: Double
    public var width: Double

    public init(wall: UInt8, x: Double, width: Double) {
        self.wall = wall
        self.x = x
        self.width = width
    }
}

struct AABB {
    var minX, maxX, minY, maxY: Double

    /// Minkowski-expansion: vaxer ladan med halva figuren, sa att figurens
    /// rorelse kan behandlas som en stralle fran dess centrum.
    func expanded(byHalfWidth hw: Double, halfHeight hh: Double) -> AABB {
        AABB(minX: minX - hw, maxX: maxX + hw, minY: minY - hh, maxY: maxY + hh)
    }
}

enum Sweep {
    /// Svept test: tracker figurens centrum fran (x0,y0) till (x1,y1) och svarar
    /// om den expanderade ladan traffas nagonstans langs vagen.
    ///
    /// Ett diskret punkttest missar tunna hinder vid hog hastighet (tunnling).
    /// Med det har testet ar stegtakten ett fidelitetsval, inte ett korrekthetsval.
    static func hits(
        box: AABB,
        fromX x0: Double, fromY y0: Double,
        toX x1: Double, toY y1: Double,
    ) -> Bool {
        let dx = x1 - x0
        let dy = y1 - y0
        var tMin = 0.0
        var tMax = 1.0

        guard slab(origin: x0, delta: dx, lo: box.minX, hi: box.maxX, &tMin, &tMax) else {
            return false
        }
        guard slab(origin: y0, delta: dy, lo: box.minY, hi: box.maxY, &tMin, &tMax) else {
            return false
        }
        return tMin <= tMax
    }

    /// Motsvarar `hits`, men for tubens (x, theta) istallet for kanalens
    /// (x, y). `slab` ateranvands oforandrat for x, som inte ar periodisk;
    /// theta jamfors mot den wrappade differensen till vaggen istallet for
    /// ett fast intervall — se spec §3.7.
    static func hitsWall(
        wall: UInt8,
        angularHalfWidth: Double,
        obstacleMinX: Double,
        obstacleMaxX: Double,
        fromX x0: Double,
        fromTheta theta0: Double,
        toX x1: Double,
        toTheta theta1: Double,
    ) -> Bool {
        let threshold = 0.5 + angularHalfWidth
        let d0 = Angle.wrappedDelta(theta0, Double(wall))
        let d1 = Angle.wrappedDelta(theta1, Double(wall))

        var tMin = 0.0
        var tMax = 1.0
        guard slab(origin: x0, delta: x1 - x0, lo: obstacleMinX, hi: obstacleMaxX, &tMin, &tMax) else {
            return false
        }
        guard slab(origin: d0, delta: d1 - d0, lo: -threshold, hi: threshold, &tMin, &tMax) else {
            return false
        }
        return tMin <= tMax
    }

    private static func slab(
        origin: Double, delta: Double, lo: Double, hi: Double,
        _ tMin: inout Double, _ tMax: inout Double,
    ) -> Bool {
        if delta == 0 {
            // Parallell med slaben: traff bara om vi redan ligger innanfor.
            return origin >= lo && origin <= hi
        }
        let inv = 1 / delta
        var t1 = (lo - origin) * inv
        var t2 = (hi - origin) * inv
        if t1 > t2 {
            swap(&t1, &t2)
        }
        tMin = max(tMin, t1)
        tMax = min(tMax, t2)
        return tMin <= tMax
    }
}

/// En punkt dar mekaniken byter. Geometry Dash-modellen: bytet ar sjalv den
/// svaraste fardigheten, och det ger 60-sekunderskorningen en dramatisk form
/// som en hastighetsramp ensam inte ger.
///
/// Bytet maste vara omisskannligt — figurens utseende, paletten och ljudets
/// tonhojd samtidigt. En spelare som misslyckas for att hen trodde fel lage var
/// aktivt skyller pa spelet, och hela premissen ar att doden alltid ar ditt fel.
public struct Portal: Sendable {
    public var x: Double
    public var mode: ControlMode

    public init(x: Double, mode: ControlMode) {
        self.x = x
        self.mode = mode
    }
}

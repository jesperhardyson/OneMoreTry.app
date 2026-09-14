/// Vad som dodade dig. Tre olika dodsreaktioner ar *diagnostik*, inte charm:
/// "du slog i taket" och "du missade flippen" ar olika lardomar, och att
/// kommunicera vilken pa 100 ms ar vad som sanker retry-kostnaden. Se spec \u{a7}8.
public enum DeathCause: Sendable, Equatable {
    case floorObstacle
    case ceilingObstacle
    /// Ett hinder pa en av tubens fyra vaggar. Vaggarna ar symmetriska, sa
    /// till skillnad fran golv/tak bar orsaken ingen ytterligare diagnostik
    /// i att peka ut vilken av de fyra.
    case wallObstacle
}

/// Allt utanfor simuleringen — ljud, haptik, rekord, senare analytics — lyssnar
/// har. Karnan anropar aldrig dem. Se spec \u{a7}2.
public enum RunEvent: Sendable, Equatable {
    case flipped(step: UInt32, direction: Sign)
    /// `clearance` i varldsenheter. Genrens mest motiverande handelse: det ar
    /// ogonblicket spelaren lar sig toleranserna. Se spec \u{a7}3.
    case nearMiss(step: UInt32, clearance: Double)
    case died(step: UInt32, cause: DeathCause)
    case modeChanged(step: UInt32, mode: ControlMode)
}

/// Synkron. Anvand inte `AsyncStream` — hopp genom cooperative pool ger obunden
/// latens och ordning som inte ar deterministisk mot frames. Se CLAUDE.md.
public protocol RunEventSink: AnyObject {
    func emit(_ event: RunEvent)
}

public struct StepResult: Sendable {
    public var state: SimState
    public var events: [RunEvent]
}

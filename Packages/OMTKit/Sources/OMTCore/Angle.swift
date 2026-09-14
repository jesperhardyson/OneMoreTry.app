/// Vinkelrymden for tuben: en sluten slinga med omkrets 4, matt i kvartsvarv.
/// Formfri — simuleringen kanner aldrig till radien eller den faktiska formen.
/// Se spec §3.1, §3.3, §3.6, §3.7.
enum Angle {
    /// Normaliserar `theta` till [0, 4). En enkel `theta + 4.0` racker inte:
    /// for ett `theta` inom en ulp av 0 fran undersidan rundar additionen till
    /// exakt 4.0, vilket ligger utanfor det halvoppna intervallet. Darfor
    /// asserteras invarianten efter normaliseringen istallet for att antas —
    /// traffar vi 4.0 exakt, dras ytterligare en period bort.
    static func wrap(_ theta: Double) -> Double {
        var t = theta
        if t >= 4 {
            t -= 4
        } else if t < 0 {
            t += 4
        }
        if t >= 4 {
            t -= 4
        }
        return t
    }

    /// Kortaste signerade avstandet fran `theta` till vagg `w`, normaliserat
    /// till [-2, 2). Halvoppet, inte symmetriskt: `.rounded()` (round to
    /// nearest, ties away from zero) ar antisymmetrisk i sitt argument och
    /// ger -2 for ena argumentordningen men +2 for den andra vid exakt
    /// motsatt vagg — de tva representerar samma vinkel (2 ≡ -2 mod 4) och
    /// maste darfor mappas till samma varde. `.rounded(.down)` (golv) pa
    /// `(d + 2) / 4` gor det: bada -2 och +2 som ravarde hamnar i samma
    /// intervallhalva och normaliseras till -2. Se
    /// `symmetric entry falls in tap direction` for varfor det spelar roll.
    static func wrappedDelta(_ theta: Double, _ w: Double) -> Double {
        let d = theta - w
        return d - 4 * ((d + 2) / 4).rounded(.down)
    }
}

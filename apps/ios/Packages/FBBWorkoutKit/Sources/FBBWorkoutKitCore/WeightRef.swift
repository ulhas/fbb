import Foundation

// Mirrors packages/types/src/index.ts WeightRef (discriminated union on `kind`).
// Decoded with JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase
// (so JSON `load_kg_male` -> CodingKey `loadKgMale`). The `kind` value stays
// snake_case at the wire level and is matched explicitly here.

public enum WeightRef: Codable, Hashable, Sendable {
    case none
    case bodyweight
    case absolute(loadKgMale: Double?, loadKgFemale: Double?, raw: String?)
    case relativeToSet(targetPosition: Int)
    case percentOfWorking(percent: Double)
    case deltaFromSet(targetPosition: Int, deltaPercent: Double, deltaPercentMax: Double?)
    case assistanceMatchRepMax(repMax: Int)

    private enum Keys: String, CodingKey {
        case kind
        case loadKgMale, loadKgFemale, raw
        case targetPosition, percent
        case deltaPercent, deltaPercentMax
        case repMax
    }

    private enum Tag: String {
        case none, bodyweight, absolute
        case relativeToSet         = "relative_to_set"
        case percentOfWorking      = "percent_of_working"
        case deltaFromSet          = "delta_from_set"
        case assistanceMatchRepMax = "assistance_match_rep_max"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let raw = try c.decode(String.self, forKey: .kind)
        guard let tag = Tag(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown WeightRef.kind: \(raw)"
            )
        }
        switch tag {
        case .none:       self = .none
        case .bodyweight: self = .bodyweight
        case .absolute:
            self = .absolute(
                loadKgMale:   try c.decodeIfPresent(Double.self, forKey: .loadKgMale),
                loadKgFemale: try c.decodeIfPresent(Double.self, forKey: .loadKgFemale),
                raw:          try c.decodeIfPresent(String.self, forKey: .raw)
            )
        case .relativeToSet:
            self = .relativeToSet(
                targetPosition: try c.decode(Int.self, forKey: .targetPosition)
            )
        case .percentOfWorking:
            self = .percentOfWorking(
                percent: try c.decode(Double.self, forKey: .percent)
            )
        case .deltaFromSet:
            self = .deltaFromSet(
                targetPosition:  try c.decode(Int.self, forKey: .targetPosition),
                deltaPercent:    try c.decode(Double.self, forKey: .deltaPercent),
                deltaPercentMax: try c.decodeIfPresent(Double.self, forKey: .deltaPercentMax)
            )
        case .assistanceMatchRepMax:
            self = .assistanceMatchRepMax(
                repMax: try c.decode(Int.self, forKey: .repMax)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .none:
            try c.encode(Tag.none.rawValue, forKey: .kind)
        case .bodyweight:
            try c.encode(Tag.bodyweight.rawValue, forKey: .kind)
        case let .absolute(male, female, raw):
            try c.encode(Tag.absolute.rawValue, forKey: .kind)
            try c.encodeIfPresent(male,   forKey: .loadKgMale)
            try c.encodeIfPresent(female, forKey: .loadKgFemale)
            try c.encodeIfPresent(raw,    forKey: .raw)
        case let .relativeToSet(position):
            try c.encode(Tag.relativeToSet.rawValue, forKey: .kind)
            try c.encode(position, forKey: .targetPosition)
        case let .percentOfWorking(percent):
            try c.encode(Tag.percentOfWorking.rawValue, forKey: .kind)
            try c.encode(percent, forKey: .percent)
        case let .deltaFromSet(position, delta, deltaMax):
            try c.encode(Tag.deltaFromSet.rawValue, forKey: .kind)
            try c.encode(position, forKey: .targetPosition)
            try c.encode(delta,    forKey: .deltaPercent)
            try c.encodeIfPresent(deltaMax, forKey: .deltaPercentMax)
        case let .assistanceMatchRepMax(repMax):
            try c.encode(Tag.assistanceMatchRepMax.rawValue, forKey: .kind)
            try c.encode(repMax, forKey: .repMax)
        }
    }
}

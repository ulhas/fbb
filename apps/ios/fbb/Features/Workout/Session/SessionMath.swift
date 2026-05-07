import Foundation

// Small pure helpers used across the engine and views. Kept in one file
// because they have no internal state and live or die together.

enum SessionMath {
    /// Midpoint of a min/max range, rounded down to the nearest integer.
    /// Used for "what's the prescribed reps default" — repsMin..repsMax
    /// midpoint, weightRef midpoint, etc. Returns nil only when both
    /// inputs are nil.
    static func midpoint(min lower: Int?, max upper: Int?) -> Int? {
        switch (lower, upper) {
        case let (l?, u?): return (l + u) / 2
        case let (l?, nil): return l
        case let (nil, u?): return u
        case (nil, nil): return nil
        }
    }

    static func midpoint(min lower: Double?, max upper: Double?) -> Double? {
        switch (lower, upper) {
        case let (l?, u?): return (l + u) / 2
        case let (l?, nil): return l
        case let (nil, u?): return u
        case (nil, nil): return nil
        }
    }

    /// Format a duration in seconds as `mm:ss` (or `h:mm:ss` past 1h).
    /// Always uses two-digit padding on the smaller units so the layout
    /// doesn't shift as the timer advances.
    static func formatElapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Format a countdown — same as elapsed but always shows a leading
    /// minus when the value is negative (overtime rest).
    static func formatCountdown(_ seconds: Int) -> String {
        if seconds < 0 {
            return "-" + formatElapsed(-seconds)
        }
        return formatElapsed(seconds)
    }
}

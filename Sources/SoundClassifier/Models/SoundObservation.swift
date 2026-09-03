//
//  SoundObservation.swift
//  SoundClassifier
//

import Foundation

/// What was heard, and when.
public struct SoundObservation: Sendable, Hashable, Codable {

    /// The class, as Apple names it — `dog_bark`, `glass`, `door_bell`.
    /// Underscored and lower-cased, because that is the identifier the
    /// classifier returns and translating it would make the two disagree.
    public let label: String

    /// 0–1. Apple documents no calibration for these, so they order results
    /// reliably and mean nothing in absolute terms. A `0.8` is not "80%
    /// likely"; it is "more than the 0.6 beside it".
    public let confidence: Double

    /// When the window began.
    public let start: TimeInterval

    /// When it ended.
    public let end: TimeInterval

    public var duration: TimeInterval { end - start }

    /// The label with underscores as spaces, for printing.
    public var name: String { label.replacingOccurrences(of: "_", with: " ") }
}

/// Every observation for one window, strongest first.
public struct SoundWindow: Sendable, Hashable, Codable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let observations: [SoundObservation]

    /// The strongest classification in this window.
    public var top: SoundObservation? { observations.first }
}

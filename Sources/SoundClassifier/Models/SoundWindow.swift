//
//  SoundWindow.swift
//  SoundClassifier
//

//

import Foundation

/// Every observation for one window, strongest first.
public struct SoundWindow: Sendable, Hashable, Codable {
    /// When the window begins, in seconds from the start of the file.
    public let start: TimeInterval
    /// When it ends.
    public let end: TimeInterval
    /// What was heard in it, most confident first.
    public let observations: [SoundObservation]

    /// The strongest classification in this window.
    public var top: SoundObservation? { observations.first }
}

//
//  ClassifierError.swift
//  SoundClassifier
//

import Foundation

public enum ClassifierError: Error, LocalizedError, Equatable, Sendable {

    case unreadable(String)
    case unavailable(String)
    case tooShort(seconds: Double, needs: Double)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let path):
            return "cannot read audio from \(path)"
        case .unavailable(let detail):
            return "the sound classifier is unavailable: \(detail)"
        case .tooShort(let seconds, let needs):
            return String(
                format: "the audio is %.2fs and the classifier needs at least %.1fs — "
                    + "its analysis window is fixed, so a shorter clip produces nothing at all",
                seconds, needs)
        }
    }
}

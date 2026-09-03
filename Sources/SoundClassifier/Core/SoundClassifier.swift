//
//  SoundClassifier.swift
//  SoundClassifier
//
//  Apple's own sound classifier: 303 classes, already on the machine.
//

import AVFoundation
import Foundation
import SoundAnalysis

/// Recognises everyday sounds in an audio file.
///
/// `SNClassifySoundRequest(classifierIdentifier: .version1)` — Apple's
/// built-in classifier, **already installed**. No model to download, no
/// network, no permission. 303 classes covering speech and its varieties,
/// animals, vehicles, tools, music, alarms, water, and the domestic noises a
/// room makes.
///
/// Deliberately not music analysis. `swift-music-analysis` measures BPM, key
/// and structure; this answers "what is that noise", and the two overlap only
/// in that both listen.
public enum SoundClassifier {

    /// The window the classifier works in — **fixed at 3 seconds** by the
    /// model, not by this package. Audio shorter than one window produces no
    /// results at all rather than a partial answer, which is why
    /// ``ClassifierError/tooShort(seconds:needs:)`` exists.
    public static var windowDuration: TimeInterval {
        (try? SNClassifySoundRequest(classifierIdentifier: .version1).windowDuration.seconds) ?? 3
    }

    /// Every class the classifier knows.
    public static func knownClasses() throws -> [String] {
        do {
            return try SNClassifySoundRequest(classifierIdentifier: .version1)
                .knownClassifications.sorted()
        } catch {
            throw ClassifierError.unavailable(error.localizedDescription)
        }
    }

    /// Classifies a file, window by window.
    ///
    /// - Parameters:
    ///   - overlap: How much each window shares with the last, 0–1. Higher
    ///     catches short sounds that would straddle a boundary, at
    ///     proportionally more work. Apple's default is 0.5.
    ///   - minimumConfidence: Observations below this are dropped. There is
    ///     no calibrated meaning to the number — see
    ///     ``SoundObservation/confidence`` — so this is a noise gate, not a
    ///     probability threshold.
    public static func classify(
        fileAt url: URL,
        overlap: Double = 0.5,
        minimumConfidence: Double = 0.1
    ) throws -> [SoundWindow] {

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw ClassifierError.unreadable(url.lastPathComponent)
        }

        /// Checked before the analyzer is built. A file shorter than one
        /// window yields zero results and no error, which reads as "nothing
        /// in this audio" rather than "this audio was too short to ask".
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let window = windowDuration
        guard duration >= window else {
            throw ClassifierError.tooShort(seconds: duration, needs: window)
        }

        let request: SNClassifySoundRequest
        do {
            request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.overlapFactor = min(max(overlap, 0), 0.99)
        } catch {
            throw ClassifierError.unavailable(error.localizedDescription)
        }

        let analyzer: SNAudioFileAnalyzer
        do {
            analyzer = try SNAudioFileAnalyzer(url: url)
        } catch {
            throw ClassifierError.unreadable(url.lastPathComponent)
        }
        let collector = Collector(minimumConfidence: minimumConfidence)

        do {
            try analyzer.add(request, withObserver: collector)
        } catch {
            throw ClassifierError.unavailable(error.localizedDescription)
        }

        /// Analysed synchronously. The async form hands results to a queue
        /// and returns immediately, so a command-line caller would exit
        /// before the first window was classified.
        analyzer.analyze()
        return collector.windows
    }

    /// Gathers results off the analyzer's callbacks.
    private final class Collector: NSObject, SNResultsObserving, @unchecked Sendable {
        private let minimumConfidence: Double
        private(set) var windows: [SoundWindow] = []

        init(minimumConfidence: Double) {
            self.minimumConfidence = minimumConfidence
        }

        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let result = result as? SNClassificationResult else { return }
            let start = result.timeRange.start.seconds
            let end = (result.timeRange.start + result.timeRange.duration).seconds

            let observations = result.classifications
                .filter { $0.confidence >= minimumConfidence }
                .map {
                    SoundObservation(label: $0.identifier, confidence: $0.confidence,
                                     start: start, end: end)
                }
            guard !observations.isEmpty else { return }
            windows.append(SoundWindow(start: start, end: end, observations: observations))
        }
    }
}

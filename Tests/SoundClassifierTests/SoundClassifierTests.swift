//
//  SoundClassifierTests.swift
//  SoundClassifier
//
//  Synthetic audio with a known character, plus the shape of the API.
//

import AVFoundation
import XCTest
@testable import SoundClassifier

final class ClassifierTests: XCTestCase {

    /// Writes `seconds` of audio built by `sample`, at 16 kHz mono — the rate
    /// the classifier works in, so nothing is resampled underneath the test.
    private func write(seconds: Double, _ sample: (Int, Double) -> Float) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-\(UUID().uuidString).wav")
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                   channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(seconds * 16_000)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            buffer.floatChannelData![0][i] = sample(i, 16_000)
        }
        try file.write(from: buffer)
        return url
    }

    func testTheClassifierIsPresentWithoutADownload() throws {
        let classes = try SoundClassifier.knownClasses()
        // Apple ships this. If it ever stops shipping, this is the test that
        // says so rather than every caller getting empty results.
        XCTAssertGreaterThan(classes.count, 250, "got \(classes.count)")
        XCTAssertTrue(classes.contains("speech"))
        XCTAssertTrue(classes.contains("laughter"))
    }

    func testTheWindowIsThreeSeconds() {
        // Fixed by the model, and the reason short audio fails rather than
        // returning a partial answer.
        XCTAssertEqual(SoundClassifier.windowDuration, 3, accuracy: 0.01)
    }

    func testAudioShorterThanAWindowIsRefusedRatherThanReturningNothing() throws {
        let url = try write(seconds: 1.0) { i, rate in
            sin(2 * .pi * 440 * Double(i) / rate) > 0 ? 0.3 : -0.3
        }
        defer { try? FileManager.default.removeItem(at: url) }

        // Without the guard this returns zero windows and no error, which
        // reads as "nothing in this audio" rather than "too short to ask".
        XCTAssertThrowsError(try SoundClassifier.classify(fileAt: url)) { error in
            guard case ClassifierError.tooShort = error else { return XCTFail("got \(error)") }
        }
    }

    func testItClassifiesSomethingAndOrdersItByConfidence() throws {
        let url = try write(seconds: 6.0) { i, rate in
            // A rough square-wave buzz — not any particular real sound, but
            // enough signal for the classifier to produce ordered guesses.
            let t = Double(i) / rate
            return Float(sin(2 * .pi * 300 * t) > 0 ? 0.4 : -0.4) * Float(1 + sin(2 * .pi * 3 * t))
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let windows = try SoundClassifier.classify(fileAt: url, minimumConfidence: 0)
        XCTAssertFalse(windows.isEmpty)

        for window in windows {
            XCTAssertGreaterThan(window.end, window.start)
            let confidences = window.observations.map(\.confidence)
            XCTAssertEqual(confidences, confidences.sorted(by: >), "results must be strongest first")
        }
    }

    func testTheConfidenceGateDropsResults() throws {
        let url = try write(seconds: 6.0) { i, rate in
            Float(sin(2 * .pi * 300 * Double(i) / rate)) * 0.4
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let all = try SoundClassifier.classify(fileAt: url, minimumConfidence: 0)
        let some = try SoundClassifier.classify(fileAt: url, minimumConfidence: 0.5)
        let allCount = all.reduce(0) { $0 + $1.observations.count }
        let someCount = some.reduce(0) { $0 + $1.observations.count }
        XCTAssertLessThan(someCount, allCount)
    }

    func testAnUnreadableFileIsNamed() {
        let url = URL(fileURLWithPath: "/nowhere/nothing.wav")
        XCTAssertThrowsError(try SoundClassifier.classify(fileAt: url)) { error in
            guard case ClassifierError.unreadable = error else { return XCTFail("got \(error)") }
        }
    }

    func testLabelsArePrintableWithoutBeingRenamed() {
        let o = SoundObservation(label: "dog_bark", confidence: 0.9, start: 0, end: 3)
        // The identifier stays as Apple returns it — translating it would
        // make the printed name and the filterable label disagree.
        XCTAssertEqual(o.label, "dog_bark")
        XCTAssertEqual(o.name, "dog bark")
    }
}

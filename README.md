# Swift SoundClassifier

What a sound is, using the classifier macOS already has.

```swift
import SoundClassifier

for window in try SoundClassifier.classify(fileAt: url) {
    print(window.start, window.top?.name ?? "—", window.top?.confidence ?? 0)
}

try SoundClassifier.knownClasses().count   // 303
```

## Why

`SNClassifySoundRequest(classifierIdentifier: .version1)` — Apple's built-in
classifier, **already installed**. No model to download, no network, no
permission prompt. 303 classes: speech and its varieties (shouting,
whispering, laughter, crying), animals, vehicles, tools, alarms, water, music,
and the noises a room makes.

Deliberately not music analysis.
[`swift-music-analysis`](https://github.com/arraypress/swift-music-analysis)
measures BPM, key and structure; this answers *"what is that noise"*. They
overlap only in that both listen.

## Two things the API will not tell you

**The window is fixed at 3 seconds.** Audio shorter than one window produces
**zero results and no error** — which reads as "nothing in this audio" rather
than "too short to ask". So a short file throws instead, naming both durations.

**The confidences are not calibrated.** Apple documents no meaning for them.
They order results reliably and mean nothing in absolute terms: a `0.8` is not
"80% likely", it is "more than the 0.6 beside it". `minimumConfidence` is a
noise gate, not a probability threshold, and this package says so rather than
implying otherwise by naming it one.

Labels stay exactly as the classifier returns them — `dog_bark`, not "Dog
bark" — because renaming would make the printed name and the filterable label
disagree. `name` does the prettifying at the point of printing.

## Tested

7 tests on synthetic audio: the classifier is present without a download, the
window really is 3 seconds, short audio is refused rather than silently empty,
results come back strongest-first, and the confidence gate actually drops
things.

## Licence

MIT.

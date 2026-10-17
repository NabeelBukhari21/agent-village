import AVFoundation
import Foundation

/// Sound effects the game can trigger.
enum SFX {
    case blip, select, questStart, questDone, alert, approved, denied, clank, pause, wake
    case voice(pitch: Double)
}

/// A tiny real-time synthesizer: a calm lo-fi background loop (warm pad, soft bass,
/// sparse melody, vinyl crackle) plus gentle one-shot sound effects.
final class Chiptune: @unchecked Sendable {
    static let shared = Chiptune()

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let lock = NSLock()
    private var started = false

    // Shared with the audio thread (guarded by `lock`).
    private var musicOn: Bool
    private var sfxOn: Bool
    private var sampleRate: Double = 44_100
    private var sampleIndex: Int = 0
    private var voices: [Voice] = []
    private var rng: UInt32 = 0xACE1

    init() {
        let d = UserDefaults.standard
        musicOn = d.object(forKey: "musicOn") as? Bool ?? true
        sfxOn = d.object(forKey: "sfxOn") as? Bool ?? true
    }

    var isMusicOn: Bool { lock.lock(); defer { lock.unlock() }; return musicOn }
    var isSFXOn: Bool { lock.lock(); defer { lock.unlock() }; return sfxOn }

    func setMusic(_ on: Bool) {
        lock.lock(); musicOn = on; lock.unlock()
        UserDefaults.standard.set(on, forKey: "musicOn")
    }

    func setSFX(_ on: Bool) {
        lock.lock(); sfxOn = on; if !on { voices.removeAll() }; lock.unlock()
        UserDefaults.standard.set(on, forKey: "sfxOn")
    }

    func start() {
        guard !started else { return }
        started = true
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
        sampleRate = sr > 0 ? sr : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [unowned self] _, _, frameCount, bufferList in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.render(into: buf, count: Int(frameCount))
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        do { try engine.start() } catch { started = false }
    }

    func play(_ s: SFX) {
        lock.lock(); defer { lock.unlock() }
        guard sfxOn else { return }
        let now = sampleIndex
        func notes(_ ns: [Int], step: Double, wave: Wave = .triangle, vol: Float = 0.09, decay: Double = 7) {
            for (i, n) in ns.enumerated() {
                voices.append(Voice(start: now + Int(Double(i) * step * sampleRate), freq: midi(n), freqEnd: midi(n),
                                    duration: step * 2.2, volume: vol, wave: wave, decay: decay))
            }
        }
        switch s {
        case .blip:
            voices.append(Voice(start: now, freq: 660, freqEnd: 640, duration: 0.03, volume: 0.018, wave: .triangle, decay: 25))
        case .select:
            notes([79, 84], step: 0.05, vol: 0.06, decay: 14)
        case .questStart:
            notes([72, 76, 79], step: 0.07, vol: 0.06)
        case .questDone:
            notes([72, 76, 79, 84], step: 0.09, vol: 0.08, decay: 5)
        case .alert:
            notes([84, 79, 84], step: 0.12, wave: .pulse(0.25), vol: 0.035, decay: 8)
        case .approved:
            notes([76, 79, 84, 88], step: 0.07, vol: 0.08)
        case .denied:
            notes([67, 63], step: 0.14, vol: 0.09, decay: 5)
        case .clank:
            voices.append(Voice(start: now, freq: 1200, freqEnd: 900, duration: 0.05, volume: 0.025, wave: .triangle, decay: 40))
            voices.append(Voice(start: now, freq: 0, freqEnd: 0, duration: 0.04, volume: 0.02, wave: .noise, decay: 60))
        case .pause:
            voices.append(Voice(start: now, freq: 620, freqEnd: 300, duration: 0.4, volume: 0.06, wave: .triangle, decay: 3))
        case .wake:
            voices.append(Voice(start: now, freq: 330, freqEnd: 760, duration: 0.25, volume: 0.06, wave: .triangle, decay: 4))
        case .voice(let pitch):
            for i in 0..<3 {
                let f = pitch * pow(2, Double(Int(next() % 5) - 2) / 12)
                voices.append(Voice(start: now + Int(Double(i) * 0.08 * sampleRate), freq: f, freqEnd: f * 0.94,
                                    duration: 0.06, volume: 0.025, wave: .triangle, decay: 14))
            }
        }
        if voices.count > 40 { voices.removeFirst(voices.count - 40) }
    }

    // MARK: Song data — a slow lo-fi loop (8th-note steps, 8 bars)

    private static let bpm: Double = 72
    private static let melody: [Int] = [
        76, 0, 0, 72, 0, 0, 69, 0,
        71, 0, 0, 0, 67, 0, 0, 0,
        69, 0, 72, 0, 74, 0, 0, 72,
        71, 0, 0, 0, 0, 0, -1, 0,
        74, 0, 0, 72, 0, 0, 69, 0,
        72, 0, 0, 0, 76, 0, 0, 0,
        74, 0, 72, 0, 70, 0, 0, 69,
        67, 0, 0, 0, 0, 0, -1, 0,
    ]
    // Fmaj7, Em7, Dm7, Cmaj7, Bbmaj7, Am7, Gm7, Csus/C
    private static let chords: [[Int]] = [
        [53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59],
        [46, 50, 53, 57], [45, 48, 52, 55], [43, 46, 50, 53], [48, 53, 55, 60],
    ]
    private static let roots: [Int] = [41, 40, 38, 36, 34, 33, 31, 36]

    // Music state (audio thread only)
    private var melPhase = 0.0, melFreq = 0.0, melEnv: Float = 0, melTarget: Float = 0, melAge = 0.0
    private var bassPhase = 0.0, bassFreq = 0.0, bassEnv: Float = 0
    private var padPhases = [Double](repeating: 0, count: 8)
    private var padFreqs = [Double](repeating: 0, count: 8)
    private var padEnv: Float = 0
    private var lowpass: Float = 0
    private var lastStep = -1
    private var musicFade: Float = 0

    private func render(into buf: UnsafeMutablePointer<Float>, count: Int) {
        lock.lock(); defer { lock.unlock() }
        let sr = sampleRate
        let dt = 1 / sr
        let samplesPerStep = sr * 60 / Self.bpm / 2
        for i in 0..<count {
            let n = sampleIndex + i
            var music: Float = 0

            // Smooth fade when toggling music
            musicFade += ((musicOn ? 1 : 0) - musicFade) * 0.0002
            if musicFade > 0.001 {
                let step = Int(Double(n) / samplesPerStep) % Self.melody.count
                if step != lastStep { lastStep = step; triggerStep(step) }

                // Melody: soft triangle with slow attack and gentle vibrato
                melAge += dt
                melEnv += (melTarget - melEnv) * 0.0015
                melTarget *= 0.99997
                let vib = 1 + 0.004 * sin(melAge * 2 * .pi * 5) * min(1, melAge * 2)
                melPhase = (melPhase + melFreq * vib * dt).truncatingRemainder(dividingBy: 1)
                music += Float(4 * abs(melPhase - 0.5) - 1) * melEnv * 0.06

                // Warm pad: two slightly detuned triangles per chord tone
                padEnv += (0.6 - padEnv) * 0.00004
                var pad: Float = 0
                for k in 0..<8 where padFreqs[k] > 0 {
                    padPhases[k] = (padPhases[k] + padFreqs[k] * dt).truncatingRemainder(dividingBy: 1)
                    pad += Float(4 * abs(padPhases[k] - 0.5) - 1)
                }
                music += pad * padEnv * 0.011

                // Round bass
                bassPhase = (bassPhase + bassFreq * dt).truncatingRemainder(dividingBy: 1)
                music += Float(sin(bassPhase * 2 * .pi)) * bassEnv * 0.09
                bassEnv *= 0.99996

                // Vinyl crackle
                if next() % 9000 == 0 { music += noiseSample() * 0.05 }
                music += noiseSample() * 0.0015

                // Soften everything with a one-pole low-pass
                lowpass += (music - lowpass) * 0.18
                music = lowpass * musicFade
            }

            var fx: Float = 0
            if sfxOn, !voices.isEmpty {
                for v in voices.indices {
                    let local = Double(n - voices[v].start) / sr
                    guard local >= 0, local < voices[v].duration else { continue }
                    let t = local / voices[v].duration
                    let f = voices[v].freq + (voices[v].freqEnd - voices[v].freq) * t
                    voices[v].phase = (voices[v].phase + f / sr).truncatingRemainder(dividingBy: 1)
                    let env = voices[v].volume * Float(exp(-local * voices[v].decay)) * Float(min(1, local * 300))
                    let s: Float
                    switch voices[v].wave {
                    case .pulse(let duty): s = voices[v].phase < Double(duty) ? 1 : -1
                    case .triangle: s = Float(4 * abs(voices[v].phase - 0.5) - 1)
                    case .noise: s = noiseSample()
                    }
                    fx += s * env
                }
            }
            buf[i] = max(-1, min(1, music + fx))
        }
        sampleIndex += count
        voices.removeAll { Double(sampleIndex - $0.start) / sr > $0.duration }
    }

    private func triggerStep(_ step: Int) {
        let bar = step / 8, s = step % 8
        let note = Self.melody[step]
        if note > 0 { melFreq = midi(note); melTarget = 1; melAge = 0 } else if note < 0 { melTarget = 0 }
        if s == 0 {
            let chord = Self.chords[bar]
            for (k, c) in chord.enumerated() {
                padFreqs[k * 2] = midi(c + 12)
                padFreqs[k * 2 + 1] = midi(c + 12) * 1.003
            }
        }
        if s == 0 || s == 5 {
            bassFreq = midi(Self.roots[bar])
            bassEnv = s == 0 ? 1 : 0.7
        }
    }

    private func midi(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

    private func next() -> UInt32 {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return rng
    }

    private func noiseSample() -> Float { Float(next() & 0xFFFF) / 32768 - 1 }

    private enum Wave { case pulse(Float), triangle, noise }

    private struct Voice {
        var start: Int
        var freq: Double
        var freqEnd: Double
        var duration: Double
        var volume: Float
        var wave: Wave
        var decay: Double
        var phase = 0.0
    }
}

import Foundation
import AudioKit

class KDPhaseDistortionOscillatorBank: KDInstrument {
    
    private(set) var oscillators: AKPhaseDistortionOscillatorBank = AKPhaseDistortionOscillatorBank()

    /** Dictionary to hold on notes for quick reference. Key should be the midi note, and the value should be the frequency. */
    private(set) var notes: [MIDINoteNumber: MIDINoteProperties] = [:]

    /** Reports the `MIDINoteNumber` when a note is turned on. */
    var onNoteOn: ((MIDINoteNumber) -> ())?

    /** Reports the `MIDINoteNumber` when a note is turned off. */
    var onNoteOff: ((MIDINoteNumber) -> ())?

    /** Default `.sine`.
     ```
     .sine
     .triangle
     .square
     .sawtooth
     .reverseSawtooth
     .positiveSine
     .positiveTriangle
     .positiveSquare
     .positiveSawtooth
     .positiveReverseSawtooth
     .zero
     ```
     */
    var waveform: AKTableType {
        get { return self._waveform }
        set (value) {
            self._waveform = value
            self.output.disconnectInput()
            self.connect()
        }
    }
    private var _waveform: AKTableType = .sine

    /** Default MIDI velocity is used when no velocity is passed to `play()`. Passing a velocity to `play()` does not set `self.defaultVelocity`. (Default: 120) */
    var defaultVelocity: MIDIVelocity {
        get { return self._defaultVelocity }
        set (value) {
            self._defaultVelocity = value
        }
    }
    private var _defaultVelocity: MIDIVelocity = 120

    /** Pitch bend in semitones. (Default: 0) */
    var pitchBend: Double {
        get { return self._pitchBend }
        set (value) {
            self._pitchBend = value
            self.oscillators.pitchBend = value
        }
    }
    private var _pitchBend: Double = 0.0

    /** Vibrato depth in semitones. (Default: 0) */
    var vibratoDepth: Double {
        get { return self._vibratoDepth }
        set (value) {
            self._vibratoDepth = value
            self.oscillators.vibratoDepth = value
        }
    }
    private var _vibratoDepth: Double = 0.0

    /** Vibrato rate in Hz. (Default: 0) */
    var vibratoRate: Double {
        get { return self._vibratoRate }
        set (value) {
            self._vibratoRate = value
            self.oscillators.vibratoRate = value
        }
    }
    private var _vibratoRate: Double = 0.0

    /** Amount of distortion within the range (-1, 1). 0 is no distortion. (Default: 0) */
    var phaseDistortion: Double {
        get { return self._phaseDistortion }
        set (value) {
            self._phaseDistortion = value
            self.oscillators.phaseDistortion = value
        }
    }
    private var _phaseDistortion: Double = 0.0

// //////////////////////////////
// MARK: Init
// //////////////////////////////

    override init() {
        super.init()
        self.setOutput(AKMixer(self.oscillators))
        self.connect()
    }

    init(_ waveform: AKTableType) {
        super.init()
        self.waveform = waveform
        self.connect()
    }

    convenience init(waveform: AKTableType = .sine, distortion: Double = 0, _ adsr: ADSR = ADSR.defaultShort()) {
        self.init(waveform)
        self.adsr = adsr
        self.phaseDistortion = distortion
    }

// //////////////////////////////
// MARK: Private and Overrides
// //////////////////////////////

    /**
     `KDOscillatorBank` does not use the `self.envelope` property. ADSR parameters are applied to the internal `AKOscillatorBank` envelope.
     */
    override func setEnvelope(_ node: AKNode) {
        print("KDOscillatorBank does not use the `self.envelope` property. ADSR parameters are applied to the internal AKOscillatorBank envelope.")
    }

    private func connect() {
        self.oscillators = AKPhaseDistortionOscillatorBank(waveform: AKTable(self.waveform))
        self.oscillators.rampDuration = 0
        self.oscillators.vibratoDepth = 0
        self.oscillators.vibratoRate = 0
        self.oscillators.pitchBend = 0
        self.prepareEnvelopeWithADSR()
        self.connectToOutput(input: self.oscillators)
    }

// //////////////////////////////
// MARK: ADSR
// //////////////////////////////

    private func prepareEnvelopeWithADSR() {
        self.oscillators.attackDuration = self.adsr.a
        self.oscillators.decayDuration = self.adsr.d
        self.oscillators.sustainLevel = self.adsr.s
        self.oscillators.releaseDuration = self.adsr.r
    }

    override func setAttackDuration(_ duration: Double) {
        super.setAttackDuration(duration)
        self.oscillators.attackDuration = duration
    }

    override func setDecayDuration(_ duration: Double) {
        super.setDecayDuration(duration)
        self.oscillators.decayDuration = duration
    }

    override func setSustainLevel(_ level: Double) {
        super.setSustainLevel(level)
        self.oscillators.sustainLevel = level
    }

    override func setReleaseDuration(_ duration: Double) {
        super.setReleaseDuration(duration)
        self.oscillators.releaseDuration = duration
    }

    override func setADSR(a: Double, d: Double, s: Double, r: Double) {
        self.setAttackDuration(a)
        self.setDecayDuration(d)
        self.setSustainLevel(s)
        self.setReleaseDuration(r)
    }

// //////////////////////////////
// MARK: Play
// //////////////////////////////

    /**
     Uses the passed velocity parameter, but does not set `self.defaultVelocity`.
     */
    func play(_ note: MIDINoteNumber, velocity: MIDIVelocity) {
        self.oscillators.play(noteNumber: note, velocity: velocity)
        self.notes[note] = MIDINoteProperties(frequency: note.midiNoteToFrequency(), velocity: velocity)
        self.onNoteOn?(note)
    }

    func play(_ note: MIDINoteNumber) {
        self.play(note, velocity: self.defaultVelocity)
    }

    func play(_ notes: [MIDINoteNumber]) {
        notes.forEach({ note in
            self.play(note)
        })
    }

    func play(_ notes: [MIDINoteNumber], velocities: [MIDIVelocity]) {
        for (index, _) in notes.enumerated() {
            self.play(notes[index], velocity: velocities[index])
        }
    }

    /**
     Stop the passed note.
     */
    func stop(_ note: MIDINoteNumber) {
        self.oscillators.stop(noteNumber: note)
        self.notes.removeValue(forKey: note)
        self.onNoteOff?(note)
    }

    /**
     Stop the passed notes.
     */
    func stop(_ notes: [MIDINoteNumber]) {
        notes.forEach({ note in
            self.stop(note)
        })
    }

    /**
     Stop all notes.
     */
    override func off() {
        self.notes.forEach({ note, properties in
            self.stop(note)
        })
    }

}

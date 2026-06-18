// CreateThoughtSheet.swift
// Pointward › Views
//
// [pairing-retire extraction-prep] Moved VERBATIM out of PingView.swift (which is
// being retired with the pairing era). CreateThoughtSheet is LIVE — used by
// EmojiPickerView and ProSetupView — so it lives in its own file now, independent of
// the dead PingView. No logic change; type name + init signature identical.

import SwiftUI

// MARK: - Create your own

/// The unified creation sheet: pick an emoji (native keyboard), choose its
/// sound (record your own or a preset voice), optionally name it, save.
struct CreateThoughtSheet: View {

    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var store: CustomThoughtStore
    var editing: CustomThought? = nil   // pre-fills when editing an existing one
    @Environment(\.dismiss) private var dismiss

    private enum SoundChoice { case record, preset, phone }

    @State private var chosenEmoji   = ""
    @State private var thoughtName   = ""               // optional, step 3
    // [3/5] Recording retired (no microphone) — default to a curated preset.
    @State private var soundChoice: SoundChoice = .preset
    @State private var presetToken: String? = nil
    @State private var systemSoundID: UInt32? = nil     // Apple system sound
    @State private var keepExistingRecording = false   // editing a recorded thought
    @State private var recordPulse   = false
    @State private var errorMessage: String?
    @FocusState private var emojiFocused: Bool

    private let lavender   = Color(hex: "#c4a8d4")
    private let lavenderHi = Color(hex: "#e0ccee")

    // [registry 2026-06-13] Preset emoji read from CuratedEmoji.all — was a
    // hardcoded ["💜","💋","🤗",…] list. Source of truth: CuratedEmoji.
    private let presets = CuratedEmoji.all.map { $0.emoji }

    private var canSave: Bool {
        guard !chosenEmoji.isEmpty else { return false }
        switch soundChoice {
        case .record: return false   // [3/5] recording retired — unreachable
        case .preset: return presetToken != nil
        case .phone:  return systemSoundID != nil
        }
    }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text(editing == nil ? "create your own" : "edit your thought")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 22)

                    // a) The emoji — native keyboard; first tap auto-selects,
                    // keyboard dismisses itself, no return key needed
                    sectionLabel("its emoji")
                    TextField("tap to pick an emoji", text: $chosenEmoji)
                        .focused($emojiFocused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40))
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .background(DesignTokens.Color.backgroundCard)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(chosenEmoji.isEmpty
                                        ? DesignTokens.Color.borderMid
                                        : DesignTokens.Color.accentMid, lineWidth: 1)
                        )
                        .onChange(of: chosenEmoji) { _, new in
                            guard let last = new.last else { return }
                            chosenEmoji  = String(last)   // auto-select the tapped emoji
                            emojiFocused = false          // dismiss keyboard immediately
                        }
                        .padding(.bottom, 18)

                    // b) The sound — [3/5] "record your own" retired (no mic);
                    // choose a curated preset voice or a warm phone sound.
                    sectionLabel("its sound")
                    Picker("", selection: $soundChoice) {
                        // Text("record your own").tag(SoundChoice.record)
                        Text("preset").tag(SoundChoice.preset)
                        Text("phone sounds").tag(SoundChoice.phone)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 14)

                    Group {
                        switch soundChoice {
                        case .record: presetSection   // recording retired → preset
                        case .preset: presetSection
                        case .phone:  phoneSoundSection
                        }
                    }
                    .padding(.bottom, 18)

                    // Step 3 — optional name (leave empty to skip)
                    sectionLabel("name this one")
                    TextField("dad's laugh · our song", text: $thoughtName)
                        .formInput()
                        .padding(.bottom, 22)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignTokens.Font.caption)
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                    }

                    // Save / cancel
                    HStack(spacing: 12) {
                        Button {
                            recorder.discardTake()
                            dismiss()
                        } label: {
                            Text("cancel")
                                .font(DesignTokens.Font.label)
                                .foregroundColor(DesignTokens.Color.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                        .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                                )
                        }

                        Button {
                            save()
                        } label: {
                            Text("save")
                                .font(.system(size: 15, weight: canSave ? .semibold : .regular))
                                .foregroundColor(DesignTokens.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(DesignTokens.Color.accentStrong)
                                .cornerRadius(DesignTokens.Radius.button)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                        .stroke(canSave ? DesignTokens.Color.accentSoft
                                                        : Color.clear, lineWidth: 1.2)
                                )
                                // The glow: save lights up the moment it's ready
                                .shadow(color: DesignTokens.Color.accentMid.opacity(canSave ? 0.6 : 0),
                                        radius: 10)
                                .scaleEffect(canSave ? 1.03 : 1.0)
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: canSave)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 26)
            }
        }
        .animation(.easeOut(duration: 0.25), value: soundChoice)
        .animation(.easeOut(duration: 0.25), value: recorder.hasRecording)
        .onAppear {
            // Editing: pre-fill from the existing thought
            if let editing {
                chosenEmoji = editing.emoji
                thoughtName = editing.name ?? ""
                switch editing.sound {
                case .preset(let token):
                    soundChoice = .preset
                    presetToken = token
                case .system(let soundID):
                    soundChoice = .phone
                    systemSoundID = soundID
                case .recording:
                    // [3/5] Legacy recorded thought — recording is retired, so
                    // editing falls back to choosing a preset voice.
                    soundChoice = .preset
                    keepExistingRecording = false
                }
            }
        }
        .onDisappear { recorder.discardTake() }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Font.overline)
            .foregroundColor(DesignTokens.Color.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    // MARK: Record

    private var recordSection: some View {
        VStack(spacing: 12) {
            Button {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.beginRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording
                              ? Color.red.opacity(recordPulse ? 0.85 : 0.55)
                              : DesignTokens.Color.accentStrong)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(recorder.isRecording ? Color.red : DesignTokens.Color.accentMid,
                                lineWidth: 1.5)
                        .frame(width: 82, height: 82)
                        .scaleEffect(recorder.isRecording && recordPulse ? 1.08 : 1.0)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
            }
            .onChange(of: recorder.isRecording) { _, recording in
                if recording {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        recordPulse = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { recordPulse = false }
                }
            }

            // Live waveform
            HStack(spacing: 3) {
                ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(lavender.opacity(0.85))
                        .frame(width: 3, height: 4 + level * 34)
                }
            }
            .frame(height: 40)
            .animation(.easeOut(duration: 0.06), value: recorder.levels)

            Text(recorder.isRecording
                 ? String(format: "0:0%.0f / 0:03", min(3, recorder.elapsed.rounded(.down)))
                 : (recorder.hasRecording ? "recorded ✓"
                    : keepExistingRecording ? "keeping your current recording — record to replace"
                                            : "up to 3 seconds"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Color.textMuted)

            if recorder.hasRecording {
                HStack(spacing: 14) {
                    Button {
                        recorder.playPreview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("preview")
                        }
                        .font(DesignTokens.Font.caption)
                        .foregroundColor(lavenderHi)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(DesignTokens.Color.borderMid, lineWidth: 1))
                    }
                    Button("retake") {
                        recorder.discardTake()
                    }
                    .font(DesignTokens.Font.caption)
                    .foregroundColor(DesignTokens.Color.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Presets

    private var presetSection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
            spacing: 8
        ) {
            ForEach(presets, id: \.self) { token in
                Button {
                    presetToken = token
                    SoundEngine.shared.play(for: token)   // audition on tap
                } label: {
                    Text(token)
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(presetToken == token
                                    ? DesignTokens.Color.accentStrong
                                    : DesignTokens.Color.backgroundCard)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(presetToken == token
                                        ? DesignTokens.Color.accentMid
                                        : DesignTokens.Color.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: Phone sounds (Apple system sounds — curated, warm only)

    private var phoneSoundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["notification", "alert", "ui"], id: \.self) { category in
                let entries = SystemSoundLibrary.curated.filter { $0.category == category }
                if !entries.isEmpty {
                    Text(category)
                        .font(.system(size: 10, weight: .medium))
                        .kerning(1.5)
                        .foregroundColor(DesignTokens.Color.textDim)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(entries) { entry in
                            Button {
                                // Tap to preview; the tap also selects
                                systemSoundID = entry.id
                                SystemSoundLibrary.play(entry.id)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: systemSoundID == entry.id
                                          ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.system(size: 10))
                                    Text(entry.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(systemSoundID == entry.id
                                                 ? DesignTokens.Color.textPrimary
                                                 : DesignTokens.Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(systemSoundID == entry.id
                                            ? DesignTokens.Color.accentStrong
                                            : DesignTokens.Color.backgroundCard)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(systemSoundID == entry.id
                                                ? DesignTokens.Color.accentMid
                                                : DesignTokens.Color.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Text("tap to hear · plays when your emoji is sent")
                .font(.system(size: 10, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textDim)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else { return }
        if editing == nil && store.isFull { return }
        errorMessage = nil

        // Keep the id stable when editing (recordings live at custom-<id>.m4a)
        var thought = editing ?? CustomThought(emoji: chosenEmoji, name: nil, sound: .recording)
        thought.emoji = chosenEmoji
        let trimmedName = thoughtName.trimmingCharacters(in: .whitespaces)
        thought.name = trimmedName.isEmpty ? nil : trimmedName

        switch soundChoice {
        case .preset:
            guard let token = presetToken else { return }
            thought.sound = .preset(token)
        case .phone:
            guard let soundID = systemSoundID else { return }
            thought.sound = .system(soundID)
        case .record:
            thought.sound = .recording
            if recorder.hasRecording {
                guard recorder.saveTake(to: CustomThoughtStore.soundURL(for: thought.id)) else {
                    errorMessage = "Couldn't save the recording — try recording again."
                    return
                }
            } else if !keepExistingRecording {
                return   // nothing to save
            }
        }

        if editing == nil {
            store.add(thought)
        } else {
            store.update(thought)
        }

        HapticEngine.saved()
        recorder.discardTake()
        dismiss()
    }
}

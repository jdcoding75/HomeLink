// ConnectView.swift
// Pointward › Views
//
// The one place all connection UI lives: your pairing link (tap to copy,
// send via iMessage, share), or enter someone else's code.

import SwiftUI
import MessageUI

struct ConnectView: View {

    @EnvironmentObject var people: PeopleManager
    @Environment(\.dismiss) private var dismiss

    @State private var code: String? = SupabaseService.localPairingCode
    @State private var showCopied = false
    @State private var copyGlow = false
    @State private var showMessageComposer = false
    @State private var codeInput = ""
    @State private var isBusy = false
    @State private var connected = false
    @State private var errorMessage: String?

    private static let lavender = Color(hex: "#c4a8d4")
    private static let green    = Color(hex: "#5dcaa5")

    private var pairURL: String {
        code.map { AppLinks.pairLink(code: $0) } ?? AppLinks.website
    }
    private var inviteText: String {
        AppLinks.inviteMessage(pairingCode: code)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        Text("connect with someone")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .padding(.top, 18)

                        Text("share your link or enter their code")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(DesignTokens.Color.textMuted)
                            .padding(.bottom, 4)

                        if connected {
                            // ── Success — compasses linked ─────────────────
                            VStack(spacing: 10) {
                                Text("🧭")
                                    .font(.system(size: 44))
                                Text("connected ✓")
                                    .font(.system(size: 20, weight: .semibold, design: .serif))
                                    .foregroundColor(Self.green)
                                Text("your compasses are now linked")
                                    .font(.system(size: 13, design: .serif).italic())
                                    .foregroundColor(DesignTokens.Color.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(Self.green.opacity(0.07))
                            .cornerRadius(DesignTokens.Radius.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                                    .stroke(Self.green.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Self.green.opacity(0.25), radius: 12)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        } else {
                            // ── Your link ──────────────────────────────────
                            VStack(alignment: .leading, spacing: 8) {
                                Text("YOUR LINK")
                                    .font(.system(size: 10, weight: .medium))
                                    .kerning(2)
                                    .foregroundColor(DesignTokens.Color.textMuted)

                                Button {
                                    UIPasteboard.general.string = pairURL
                                    HapticEngine.saved()
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showCopied = true
                                        copyGlow = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(.easeIn(duration: 0.4)) {
                                            showCopied = false
                                            copyGlow = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(pairURL.replacingOccurrences(of: "https://", with: ""))
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(DesignTokens.Color.accentSoft)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Spacer()
                                        Text(showCopied ? "copied ✓" : "copy")
                                            .font(.system(size: 11))
                                            .foregroundColor(showCopied ? Self.green
                                                                        : DesignTokens.Color.textDim)
                                    }
                                    .padding(13)
                                    .background(DesignTokens.Color.backgroundCard)
                                    .cornerRadius(13)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13)
                                            .stroke(copyGlow ? Self.lavender
                                                             : DesignTokens.Color.borderMid,
                                                    lineWidth: 1)
                                    )
                                    .shadow(color: Self.lavender.opacity(copyGlow ? 0.5 : 0), radius: 9)
                                }
                                .buttonStyle(.plain)
                            }

                            // ── Primary: iMessage ─────────────────────────
                            Button {
                                if MFMessageComposeViewController.canSendText() {
                                    showMessageComposer = true
                                }
                            } label: {
                                Text("📱 send via iMessage")
                                    .font(DesignTokens.Font.label)
                                    .foregroundColor(DesignTokens.Color.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignTokens.Spacing.md)
                                    .background(DesignTokens.Color.accentStrong)
                                    .cornerRadius(DesignTokens.Radius.button)
                            }
                            .opacity(MFMessageComposeViewController.canSendText() ? 1 : 0.4)
                            .disabled(!MFMessageComposeViewController.canSendText())

                            // ── Secondary: anywhere else ───────────────────
                            ShareLink(item: inviteText) {
                                Text("📤 share another way")
                                    .font(DesignTokens.Font.label)
                                    .foregroundColor(DesignTokens.Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignTokens.Spacing.md)
                                    .background(DesignTokens.Color.backgroundCard)
                                    .cornerRadius(DesignTokens.Radius.button)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.button)
                                            .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                                    )
                            }

                            // ── or ─────────────────────────────────────────
                            HStack {
                                Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                                Text("or")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignTokens.Color.textDim)
                                Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                            }
                            .padding(.vertical, 2)

                            // ── Enter their code ───────────────────────────
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ENTER THEIR CODE")
                                    .font(.system(size: 10, weight: .medium))
                                    .kerning(2)
                                    .foregroundColor(DesignTokens.Color.textMuted)

                                HStack(spacing: 10) {
                                    Text("POINT ·")
                                        .font(.system(size: 17, design: .monospaced))
                                        .foregroundColor(DesignTokens.Color.textMuted)
                                    TextField("_ _ _ _", text: $codeInput)
                                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                        .foregroundColor(DesignTokens.Color.accentSoft)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .onChange(of: codeInput) { _, new in
                                            // Auto-format: 4 uppercase alphanumerics max
                                            let cleaned = new.uppercased()
                                                .filter { $0.isLetter || $0.isNumber }
                                            codeInput = String(cleaned.suffix(4))
                                        }
                                }
                                .padding(13)
                                .background(DesignTokens.Color.backgroundCard)
                                .cornerRadius(13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(DesignTokens.Color.borderMid, lineWidth: 1)
                                )

                                if codeInput.count == 4 {
                                    Button {
                                        connect()
                                    } label: {
                                        Text(isBusy ? "connecting…" : "connect →")
                                            .font(DesignTokens.Font.label)
                                            .foregroundColor(DesignTokens.Color.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(DesignTokens.Spacing.md)
                                            .background(DesignTokens.Color.accentStrong)
                                            .cornerRadius(DesignTokens.Radius.button)
                                            .shadow(color: Self.lavender.opacity(0.4), radius: 8)
                                    }
                                    .disabled(isBusy)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(DesignTokens.Font.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .animation(.easeOut(duration: 0.25), value: codeInput.count == 4)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DesignTokens.Color.accentSoft)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMessageComposer) {
            MessageComposerView(body: inviteText)
        }
        .onAppear {
            // Make sure a code exists (signed-in users only)
            if code == nil, SupabaseService.localUserID != nil {
                Task { code = try? await SupabaseService.shared.myPairingCode() }
            }
        }
    }

    private func connect() {
        guard SupabaseService.localUserID != nil else {
            errorMessage = "Sign in first (Settings → account)."
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                let result = try await SupabaseService.shared.redeem("POINT-\(codeInput)")
                people.bindConnection(friendID: result.ownerID)
                HapticEngine.connectionFelt()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    connected = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - iMessage composer wrapper

struct MessageComposerView: UIViewControllerRepresentable {

    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismissAction: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismissAction = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            dismissAction()
        }
    }
}

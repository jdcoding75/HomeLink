// ShareSheet.swift
// Pointward › Utilities
//
// ⚠️ DEBUG ONLY — wrapped in `#if DEBUG` so it cannot compile into a release /
// TestFlight build. Phase 2 Build 3 GUARDRAIL: /m/[id] links are NOT openable
// until Build 4, so the share sheet must never appear in a path a real
// recipient could be sent from. Keeping the presenter itself DEBUG-only means
// there is no way to ship it. Joshua tests the sheet in dev and chooses whether
// to actually send anything.

#if DEBUG
import UIKit

enum ShareSheet {

    /// Present the iOS share sheet (UIActivityViewController) with `text`, from
    /// the top-most view controller of the active window scene. No-ops if no
    /// window is available. NEVER auto-shares — the user picks the destination.
    @MainActor
    static func present(_ text: String) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let scene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var top = window.rootViewController
        else { return }

        while let presented = top.presentedViewController { top = presented }

        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad requires a popover anchor or it crashes.
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                    width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }
}
#endif

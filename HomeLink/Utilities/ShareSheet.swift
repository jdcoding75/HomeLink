// ShareSheet.swift
// Pointward › Utilities
//
// [phase2 stage A] LIVE — the imperative share-sheet presenter for the link send
// (PATH-2 "a link for everyone"). The Build-3 `#if DEBUG` guardrail ("/m/ links
// aren't openable until Build 4") is obsolete — links open since 4a + the web page
// is live. NEVER auto-shares: the user picks the destination.

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

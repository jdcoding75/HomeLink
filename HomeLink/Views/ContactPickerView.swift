// ContactPickerView.swift
// Pointward › Views
//
// UIKit bridges for the add-person flow:
//   • ContactPickerView — wraps CNContactPickerViewController. The picker runs
//     out-of-process and only hands back the contact the user taps, so it works
//     even before Contacts permission is granted (the usage description is
//     declared in Info.plist for completeness / future full-access features).
//   • ActivityShareSheet — wraps UIActivityViewController for the post-save
//     "invite them to Pointward" share sheet.

import SwiftUI
import ContactsUI

struct ContactPickerView: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void

        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

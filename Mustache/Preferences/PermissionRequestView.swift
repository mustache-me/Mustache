//
//  PermissionRequestView.swift
//  Mustache
//
//  Permission request dialog view
//

import SwiftUI

struct PermissionRequestView: View {
    let onOpenSystemPreferences: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            // Title
            Text("Accessibility Permission Required")
                .font(.title)
                .fontWeight(.bold)

            // Explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("Mustache needs Accessibility permissions to:")
                    .font(.headline)

                PermissionReasonRow(
                    icon: "eye.fill",
                    text: "Monitor running applications and their windows"
                )

                PermissionReasonRow(
                    icon: "keyboard.fill",
                    text: "Capture global keyboard shortcuts"
                )

                PermissionReasonRow(
                    icon: "arrow.left.arrow.right",
                    text: "Switch between applications quickly"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Instructions
            Text("Click the button below to open System Settings and grant Accessibility access to Mustache.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Buttons
            HStack(spacing: 12) {
                Button("Later") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Open System Settings") {
                    onOpenSystemPreferences()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500)
    }
}

struct PermissionReasonRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PermissionRequestView(
        onOpenSystemPreferences: {},
        onDismiss: {}
    )
}

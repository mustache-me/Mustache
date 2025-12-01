//
//  SizeConfigurationView.swift
//  Mustache
//
//  Size Configuration Tab
//

import SwiftUI

struct SizeConfigurationView: View {
    @ObservedObject var preferencesManager: PreferencesManager

    var body: some View {
        Form {
            Section(header: Text("Badge Size")) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        Text("Font Size: \(Int(preferencesManager.preferences.badgeStyle.fontSize))")
                            .frame(width: 100, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { Double(preferencesManager.preferences.badgeStyle.fontSize) },
                                set: { newValue in
                                    preferencesManager.preferences.badgeStyle.fontSize = CGFloat(newValue)
                                    preferencesManager.savePreferences()
                                }
                            ),
                            in: 8 ... 32,
                            step: 1
                        )
                    }

                    HStack(spacing: 20) {
                        Text("Padding: \(Int(preferencesManager.preferences.badgeStyle.padding))")
                            .frame(width: 100, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { Double(preferencesManager.preferences.badgeStyle.padding) },
                                set: { newValue in
                                    preferencesManager.preferences.badgeStyle.padding = CGFloat(newValue)
                                    preferencesManager.savePreferences()
                                }
                            ),
                            in: 2 ... 12,
                            step: 1
                        )
                    }

                    HStack(spacing: 20) {
                        Text("Border Width: \(Int(preferencesManager.preferences.badgeStyle.borderWidth))")
                            .frame(width: 100, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { Double(preferencesManager.preferences.badgeStyle.borderWidth) },
                                set: { newValue in
                                    preferencesManager.preferences.badgeStyle.borderWidth = CGFloat(newValue)
                                    preferencesManager.savePreferences()
                                }
                            ),
                            in: 0 ... 4,
                            step: 0.5
                        )
                    }

                    HStack(spacing: 20) {
                        Text("Opacity: \(String(format: "%.0f%%", preferencesManager.preferences.badgeStyle.opacity * 100))")
                            .frame(width: 100, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { preferencesManager.preferences.badgeStyle.opacity },
                                set: { newValue in
                                    preferencesManager.preferences.badgeStyle.opacity = newValue
                                    preferencesManager.savePreferences()
                                }
                            ),
                            in: 0.5 ... 1.0,
                            step: 0.05
                        )
                    }
                }
            }

            HStack(alignment: .top, spacing: 20) {
                // Badge Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Badge Colors")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Text Color")
                            ColorPicker(
                                "Text Color",
                                selection: Binding(
                                    get: { preferencesManager.preferences.badgeStyle.textColor.color },
                                    set: { newColor in
                                        preferencesManager.preferences.badgeStyle.textColor = CodableColor(color: newColor)
                                        preferencesManager.savePreferences()
                                    }
                                )
                            )
                            .labelsHidden()
                        }

                        VStack(alignment: .leading) {
                            Text("Background Color")
                            ColorPicker(
                                "Background Color",
                                selection: Binding(
                                    get: { preferencesManager.preferences.badgeStyle.backgroundColor.color },
                                    set: { newColor in
                                        preferencesManager.preferences.badgeStyle.backgroundColor = CodableColor(color: newColor)
                                        preferencesManager.savePreferences()
                                    }
                                )
                            )
                            .labelsHidden()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Preview Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview")
                        .font(.headline)

                    VStack(spacing: 16) {
                        // Realistic preview with app icon (like the actual app switcher)
                        HStack(spacing: 12) {
                            // Simulate app icon with badge
                            ZStack(alignment: .topLeading) {
                                // Use Calendar app icon as example
                                let calendarIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Calendar.app")
                                Image(nsImage: calendarIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)

                                CircularBadgeView(
                                    key: "1",
                                    style: preferencesManager.preferences.badgeStyle,
                                    isHighlighted: false,
                                    showBorder: true
                                )
                                .offset(x: -3, y: -3)
                            }
                            .frame(width: 64, height: 64)

                            // Show highlighted version
                            ZStack(alignment: .topLeading) {
                                let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
                                Image(nsImage: finderIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white, lineWidth: 2.5)
                                    )

                                CircularBadgeView(
                                    key: "2",
                                    style: preferencesManager.preferences.badgeStyle,
                                    isHighlighted: true,
                                    showBorder: true
                                )
                                .offset(x: -3, y: -3)
                            }
                            .frame(width: 64, height: 64)
                        }

                        Text("This is how badges will appear in the app switcher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

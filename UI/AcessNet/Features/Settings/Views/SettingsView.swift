//
//  SettingsView.swift
//  AcessNet
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        ZStack {
            // Background
            Color("Primary")
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Account Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "ACCOUNT")

                        SettingsRow(
                            title: "Create an account",
                            showChevron: true
                        )
                    }
                    .padding(.top, 100)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 24)

                    // Preferences Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "PREFERENCES")
                            .padding(.bottom, 16)

                        SettingsRow(
                            title: "Recommendations",
                            subtitle: "Choose the one that matters most",
                            showChevron: true
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)

                        SettingsRow(
                            title: "Units",
                            showChevron: true
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)

                        SettingsRow(
                            title: "Sensitivity",
                            showChevron: true
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)

                        SettingsRow(
                            title: "Theme",
                            showChevron: true
                        )
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 24)

                    // Notifications Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "NOTIFICATIONS")
                            .padding(.bottom, 16)

                        SettingsRow(
                            title: "Favorite City",
                            subtitle: "Select the city you want to be notified",
                            showChevron: true
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)

                        SettingsToggleRow(
                            title: "Smart notifications",
                            subtitle: "They are calculated based on WHO Air...",
                            isOn: .constant(false)
                        )
                    }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 24)

                    // Performance Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "PERFORMANCE")
                            .padding(.bottom, 16)

                        // Performance Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)

                                Text("Optimized for Maximum Performance")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }

                            Text("Grid: \(appSettings.totalAirQualityZones) static zones • No animations")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))

                            Text("All air quality circles are now completely static for best performance.")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .avoidTabBar(extraPadding: 20)
            }

            // Navigation Bar
            VStack {
                HStack {
                    Spacer()

                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding()
                .background(
                    Color("Primary")
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.6))
            .tracking(1.2)
    }
}

struct SettingsRow: View {
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 16)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color("AccentColor"))
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

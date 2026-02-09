// ObservabilityDebugView.swift
// Internal-only debug UI to inspect local observability metrics.
// This screen reads from local storage only. It never calls the relay or Opik.

import SwiftUI

struct ObservabilityDebugView: View {
    @State private var stats: ObservabilityStore.Stats = ObservabilityStore.shared.stats()

    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Observability (Local)")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.textPrimary)

                    summarySection
                    lastFiveSection

                    SignalButton(title: "Refresh", style: .secondary) {
                        stats = ObservabilityStore.shared.stats()
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .navigationTitle("Observability")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { stats = ObservabilityStore.shared.stats() }
    }

    private var summarySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                metricCard(title: "Total", value: "\(stats.total)", color: Theme.Colors.primaryAccent)
                metricCard(title: "Triggered", value: "\(stats.triggered)", color: Theme.Colors.success)
                metricCard(title: "Ignored", value: "\(stats.ignored)", color: Theme.Colors.evaluationMedium)
            }

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.Colors.evaluationLow)
                Text("False Positives: \(stats.falsePositives)")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.textOnLight)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(Theme.CornerRadius.md)
    }

    private var lastFiveSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Last 5 Decisions")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.textPrimary)

            ForEach(stats.lastFive) { event in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(event.traceID.uuidString.prefix(8))
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textOnLight)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(event.decision)
                            .font(Theme.Typography.caption)
                            .foregroundColor(event.decision == "triggered" ? Theme.Colors.success : Theme.Colors.textMuted)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background((event.decision == "triggered" ? Theme.Colors.success : Theme.Colors.textMuted).opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.sm)
                    }
                    Text("Rel: \(Int(event.relevanceScore * 100))%  •  LV: \(Int(event.learningValueScore * 100))%  •  Concepts: \(event.conceptCount)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(event.timestamp, style: .time)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }
}

#Preview {
    NavigationView { ObservabilityDebugView() }
}

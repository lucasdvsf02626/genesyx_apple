import SwiftUI
import GenesyxCore

/// Insights — pH insights (from real readings) + cycle regularity, symptom heatmap, and
/// nutrition consistency (mock analytics, ported verbatim from `mockData.ts`).
struct InsightsView: View {

    @EnvironmentObject private var ph: PhRepository

    // Mock analytics, ported verbatim from the Android InsightsScreen.
    private let cycleBars = [82, 78, 90, 85, 88, 80, 92]
    private let nutritionBars = [60, 75, 70, 85, 78, 90, 82]

    var body: some View {
        let insights = PhInsightLogic.compute(ph.readings)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    PhInsightsCard(ph: insights)
                    BarsCard(
                        title: "Cycle regularity", trailing: "Last 7 cycles",
                        values: cycleBars, labels: (1...7).map { "C\($0)" }, barHeight: 128,
                        gradient: LinearGradient(colors: [GenesyxColor.primary.opacity(0.8), GenesyxColor.primary.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                        insight: "Your cycles are tracking with steady consistency — a small day-to-day variation is completely typical."
                    )
                    SymptomPatternsCard()
                    BarsCard(
                        title: "Nutrition consistency", trailing: nil,
                        values: nutritionBars, labels: ["M", "T", "W", "T", "F", "S", "S"], barHeight: 112,
                        gradient: LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue], startPoint: .top, endPoint: .bottom),
                        insight: "You've stayed close to your hydration goal four days this week — gentle progress."
                    )
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Insights").font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
            Text("Understanding your patterns helps you make informed, empowered decisions for your wellbeing.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

private struct PhInsightsCard: View {
    let ph: PhInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Urine pH").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("Open tracker").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            if !ph.hasReadings {
                Text("No pH readings yet. Log your first one on Track or Nutrition.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 12)
            } else {
                let status = ph.currentStatus ?? .optimal
                let color = Theme.color(for: status)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow("Current", color: GenesyxColor.mutedForeground)
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f", ph.currentValue ?? 0))
                                .font(.system(size: 30, weight: .semibold)).foregroundStyle(color)
                            Text(status.label.uppercased()).font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 3)
                                .background(color.opacity(0.18)).clipShape(Capsule())
                        }
                    }
                    Spacer()
                    trendBadge
                }
                .padding(.top, 14)
                HStack(spacing: 12) {
                    avgTile("7-day avg", ph.avg7)
                    avgTile("30-day avg", ph.avg30)
                }
                .padding(.top, 16)
                Text(ph.insight).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 16)
                if !ph.recommendation.isEmpty {
                    Text(ph.recommendation).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var trendBadge: some View {
        let symbol: String
        switch ph.trend {
        case .up: symbol = "arrow.up"
        case .down: symbol = "arrow.down"
        case .flat: symbol = "arrow.right"
        }
        return HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            Text("vs previous").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
        }
    }

    private func avgTile(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BarsCard: View {
    let title: String
    let trailing: String?
    let values: [Int]
    let labels: [String]
    let barHeight: CGFloat
    let gradient: LinearGradient
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                Text(title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                if let trailing { Text(trailing).font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary) }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(values.indices, id: \.self) { i in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradient)
                            .frame(height: barHeight * CGFloat(values[i]) / 100)
                        Text(labels[i]).font(.system(size: 10)).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight + 18)
            .padding(.top, 18)
            Text(insight).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 14)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct SymptomPatternsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Symptom patterns").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            VStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { c in
                            let intensity = (sin(Double(r * 7 + c) * 1.7) + 1) / 2
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GenesyxColor.primary.opacity(alpha(intensity)))
                                .frame(height: 26)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.top, 14)
            Text("Fatigue tends to ease in the second half of your cycle — useful to plan rest accordingly.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 14)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func alpha(_ intensity: Double) -> Double {
        if intensity > 0.7 { return 0.5 }
        if intensity > 0.4 { return 0.3 }
        if intensity > 0.15 { return 0.15 }
        return 0.05
    }
}

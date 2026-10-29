import SwiftUI
import Charts

/// Bar chart of each rep's relative speed score, coloured by speed class.
/// When `isInteractive` is true, tapping a bar selects that rep.
struct RepSpeedChart: View {
    let reps: [RepRecord]
    var height: CGFloat = 180
    var showThresholds = true
    var isInteractive = false
    var showAxes = true
    @Binding var selectedRep: Int?

    init(
        reps: [RepRecord],
        height: CGFloat = 180,
        showThresholds: Bool = true,
        showAxes: Bool = true,
        isInteractive: Bool = false,
        selectedRep: Binding<Int?> = .constant(nil)
    ) {
        self.reps = reps
        self.height = height
        self.showThresholds = showThresholds
        self.showAxes = showAxes
        self.isInteractive = isInteractive
        self._selectedRep = selectedRep
    }

    private let classifier = SpeedClassifier.default

    var body: some View {
        Chart {
            if showThresholds {
                RuleMark(y: .value("Fast threshold", classifier.fastLowerBound))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(SpeedClass.fast.color.opacity(0.35))
                RuleMark(y: .value("Slow threshold", classifier.slowUpperBound))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(SpeedClass.slow.color.opacity(0.35))
            }

            ForEach(reps) { rep in
                BarMark(
                    x: .value("Rep", "\(rep.number)"),
                    y: .value("Speed score", rep.speedScore),
                    width: .ratio(0.62)
                )
                .foregroundStyle(rep.speedClass.color.gradient)
                .cornerRadius(5)
                .opacity(selectedRep == nil || selectedRep == rep.number ? 1 : 0.3)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
            }
        }
        .chartXAxis(showAxes ? .automatic : .hidden)
        .chartYAxis(showAxes ? .automatic : .hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard isInteractive, let plotFrame = proxy.plotFrame else { return }
                        let x = location.x - geometry[plotFrame].origin.x
                        guard let label = proxy.value(atX: x, as: String.self),
                              let number = Int(label) else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedRep = (selectedRep == number) ? nil : number
                        }
                    }
                    .allowsHitTesting(isInteractive)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: reps.count)
        .accessibilityLabel("Rep speed chart")
        .accessibilityValue(reps.map { "Rep \($0.number): \($0.speedClass.label)" }.joined(separator: ", "))
    }
}

/// Legend explaining the speed-class colours.
struct SpeedLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(SpeedClass.allCases.reversed()) { speedClass in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(speedClass.color)
                        .frame(width: 10, height: 10)
                    Text(speedClass.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

#Preview {
    VStack {
        RepSpeedChart(reps: SampleData.sampleSetResult.reps, isInteractive: true)
        SpeedLegend()
    }
    .padding()
    .appBackground()
}

import SwiftUI

/// 취향 분석이 진행되는 동안 단계 연출을 보여주고, 완료되면 결과로 넘어가는 화면.
struct RelationshipPreferenceAnalysisView: View {
    @EnvironmentObject private var store: LoveyMomentStore
    @State private var activeStep = 0

    private let steps = [
        "고른 대화의 분위기를 읽는 중",
        "대화 온도와 거리감을 살피는 중",
        "관계 취향 4가지 결을 정리하는 중"
    ]

    var body: some View {
        ZStack {
            PoCTheme.background.ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()
                pulse
                VStack(spacing: 8) {
                    Text(isComplete ? "취향 분석이 끝났어요" : "관계 취향을 분석하고 있어요")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(isComplete
                         ? "이제 어떤 관계를 편안해하는지 함께 볼까요?"
                         : "잠깐이면 돼요. 고른 대화의 결을 모으는 중이에요.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepList
                Spacer()
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            if isComplete {
                PrimaryCTAButton(title: "취향 결과 보기", systemImage: "arrow.right") {
                    store.showDatingPreferenceProfile()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("취향 분석")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isComplete)
        .onAppear(perform: startStepAnimation)
    }

    private var isComplete: Bool {
        store.datingSignalAnalysisState == .complete
    }

    private var pulse: some View {
        ZStack {
            Circle()
                .fill(PoCTheme.primary.opacity(0.16))
                .frame(width: 132, height: 132)
                .scaleEffect(isComplete ? 1.0 : 1.12)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isComplete)
            Circle()
                .fill(PoCTheme.primary.opacity(0.28))
                .frame(width: 92, height: 92)
            Image(systemName: isComplete ? "checkmark" : "waveform.path.ecg")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    Image(systemName: stepIcon(index))
                        .font(.headline)
                        .foregroundStyle(stepDone(index) ? PoCTheme.primary : .white.opacity(0.3))
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(stepDone(index) ? .white : .white.opacity(0.5))
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 4)
    }

    private func stepDone(_ index: Int) -> Bool {
        isComplete || index <= activeStep
    }

    private func stepIcon(_ index: Int) -> String {
        if isComplete || index < activeStep { return "checkmark.circle.fill" }
        if index == activeStep { return "circle.dotted" }
        return "circle"
    }

    private func startStepAnimation() {
        guard store.datingSignalAnalysisState == .analyzing else { return }
        for step in 1..<steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.6) {
                if store.datingSignalAnalysisState == .analyzing {
                    activeStep = step
                }
            }
        }
    }
}

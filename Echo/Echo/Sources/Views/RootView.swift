import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: EchoStore
    var body: some View {
        ZStack {
            Palette.bgGradient.ignoresSafeArea()
            switch store.screen {
            case .loading:  LoadingView()
            case .coldOpen: ColdOpenView()
            case .question: QuestionView()
            case .seal:     SealView()
            case .reveal:   RevealView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.screen)
    }
}

struct LoadingView: View {
    @State private var on = false
    var body: some View {
        Text("ECHO")
            .font(EType.serif(40, .bold)).tracking(8)
            .foregroundStyle(Palette.ink)
            .opacity(on ? 1 : 0.25)
            .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { on = true } }
    }
}

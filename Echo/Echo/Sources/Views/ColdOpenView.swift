import SwiftUI

// No login wall. One line, then the two ways to play.
struct ColdOpenView: View {
    @EnvironmentObject var store: EchoStore
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s6) {
            HStack {
                Spacer()
                Button { Haptics.tap(); store.showIntro() } label: {
                    Label("How it works", systemImage: "questionmark.circle")
                        .font(EType.small).foregroundStyle(Palette.inkSoft)
                }
            }
            .opacity(appear ? 1 : 0)
            Spacer()
            Text("ECHO")
                .font(EType.label).tracking(6).foregroundStyle(Palette.indigo)
                .opacity(appear ? 1 : 0)
            Text("Two ways to play.")
                .font(EType.serif(32, .semibold)).foregroundStyle(Palette.ink)
                .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 12)

            VStack(spacing: Metrics.s3) {
                modeCard(title: "Read me",
                         subtitle: "21 questions — then I tell you who you are.",
                         icon: "sparkles", action: store.chooseMirror)
                modeCard(title: "Guess my word",
                         subtitle: "Think of anything. I'll guess it in 21 questions.",
                         icon: "questionmark.bubble", action: store.chooseClassic)
            }
            .opacity(appear ? 1 : 0)

            if let err = store.errorText {
                Text(err).font(EType.small).foregroundStyle(Palette.indigo)
            }
            Spacer()
            Text("Make-believe is the point — your answers are yours. Echo reflects, it doesn't diagnose.")
                .font(EType.small).foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Metrics.s8).padding(.vertical, Metrics.s10)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { appear = true } }
    }

    private func modeCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: Metrics.s4) {
                Image(systemName: icon).font(.system(size: 24)).foregroundStyle(Palette.indigo).frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(EType.serif(20, .semibold)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(EType.small).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Palette.inkFaint)
            }
            .padding(Metrics.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain).disabled(store.starting)
    }
}

import SwiftUI

// No login wall. One full-bleed line, one Begin button.
struct ColdOpenView: View {
    @EnvironmentObject var store: EchoStore
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s6) {
            Spacer()
            Text("ECHO")
                .font(EType.label).tracking(6).foregroundStyle(Palette.indigo)
                .opacity(appear ? 1 : 0)

            Text("21 questions.\nThen I'll tell you who you are.")
                .font(EType.serif(32, .semibold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(6)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)

            Text("Answer honestly. There are no wrong answers — only revealing ones.")
                .font(EType.body).foregroundStyle(Palette.inkSoft)
                .opacity(appear ? 1 : 0)

            Spacer()

            if let err = store.errorText {
                Text(err).font(EType.small).foregroundStyle(Palette.indigo)
            }
            Button {
                Haptics.tap(); store.begin()
            } label: {
                HStack {
                    Text(store.starting ? "Beginning…" : "Begin")
                        .font(EType.serif(20, .semibold))
                    if !store.starting { Image(systemName: "arrow.right") }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Palette.indigo)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            }
            .disabled(store.starting)
            .opacity(appear ? 1 : 0)

            Text("Make-believe is the point — your answers are yours. Echo reflects, it doesn't diagnose.")
                .font(EType.small).foregroundStyle(Palette.inkFaint)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Metrics.s8)
        .padding(.vertical, Metrics.s10)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { appear = true } }
    }
}

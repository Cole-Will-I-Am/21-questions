import SwiftUI

// Appears once, at Q3: a tactile lock + the visible hash. The proof that Echo committed early.
struct SealView: View {
    @EnvironmentObject var store: EchoStore
    @State private var sealed = false

    private var remaining: Int { max(1, store.total - (store.turn?.n ?? 3) + 1) }

    var body: some View {
        VStack(spacing: Metrics.s6) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgRaised2)
                    .frame(width: 188, height: 138)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.indigo.opacity(0.5), lineWidth: 1))
                    .shadow(color: Palette.indigo.opacity(sealed ? 0.3 : 0), radius: 24)
                Image(systemName: sealed ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(Palette.indigo)
                    .scaleEffect(sealed ? 1 : 1.25)
            }
            .scaleEffect(sealed ? 1 : 0.92)

            Text("Sealed.")
                .font(EType.serif(30, .bold)).foregroundStyle(Palette.ink)

            Text("I've written down a specific guess about who you are — and locked it. I can't change it now. In \(remaining) question\(remaining == 1 ? "" : "s"), I'll open it, and you'll see I didn't move the goalposts.")
                .font(EType.body).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let h = store.sealHash {
                Text("sha-256 · \(String(h.prefix(28)))…")
                    .font(EType.mono).foregroundStyle(Palette.inkFaint)
                    .padding(.horizontal, Metrics.s3).padding(.vertical, 6)
                    .background(Palette.bgRaised).clipShape(Capsule())
            }
            Spacer()
            Button { Haptics.tap(); store.continueFromSeal() } label: {
                Text("Keep going").font(EType.serif(20, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Palette.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
            }
        }
        .padding(.horizontal, Metrics.s8).padding(.vertical, Metrics.s10)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.2)) { sealed = true } }
    }
}

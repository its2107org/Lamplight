import SwiftUI

/// Shown when the night's five pieces are read: what you learnt, and then lights out.
struct GoodnightView: View {
    let night: Night
    let close: () -> Void
    @EnvironmentObject private var list: ReadingList
    @EnvironmentObject private var progress: ReadingProgress
    @State private var appeared = false

    private var nightsDone: Int { list.lineup.map { progress.completedNights(in: $0) } ?? 0 }
    private var upNext: Night? { list.lineup?.nights.first { $0.day > night.day } }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Palette.ember.opacity(0.16), Palette.background], center: .top, startRadius: 10, endRadius: 700)
                .ignoresSafeArea()
            Palette.background.opacity(0.4).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(LinearGradient(colors: [Palette.glow, Palette.ember], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.ember.opacity(0.5), radius: 30)
                        .padding(.top, 70)

                    VStack(spacing: 10) {
                        Text("That's tonight done.")
                            .font(.lamp(40, .medium))
                            .foregroundStyle(Palette.ink)
                        Text(nightsDone == 1 ? "Your first night of the challenge." : "\(nightsDone) nights of the challenge so far.")
                            .font(.lamp(18))
                            .foregroundStyle(Palette.muted)
                    }
                    .multilineTextAlignment(.center)

                    if let learn = night.learn {
                        VStack(spacing: 10) {
                            Text("WHAT YOU LEARNT").font(.label(11)).tracking(1.8).foregroundStyle(Palette.ember)
                            Text(learn)
                                .font(.lamp(21))
                                .foregroundStyle(Palette.ink.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(26)
                        .frame(maxWidth: 560)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Palette.surface.opacity(0.8)))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line, lineWidth: 1))
                    }

                    if let next = upNext {
                        VStack(spacing: 6) {
                            Text("NEXT TIME").font(.label(11)).tracking(1.8).foregroundStyle(Palette.faint)
                            Text("\(Self.dayName(next.day)): \(next.headline)")
                                .font(.lamp(18, .medium))
                                .foregroundStyle(Palette.muted)
                            if let field = next.field {
                                Text(field).font(.lamp(15).italic()).foregroundStyle(Palette.faint)
                            }
                        }
                        .multilineTextAlignment(.center)
                    }

                    Button(action: close) {
                        Text("Goodnight").frame(minWidth: 200)
                    }
                    .buttonStyle(LampButtonStyle(filled: false))
                    .padding(.top, 8)

                    Text("Put the screen down and let the ideas settle.")
                        .font(.lamp(14).italic())
                        .foregroundStyle(Palette.faint)
                        .padding(.bottom, 50)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { appeared = true } }
    }

    static func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

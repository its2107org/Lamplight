import SwiftUI

/// The home screen: tonight's reading, or a quiet note on nights off.
struct TonightView: View {
    @EnvironmentObject private var list: ReadingList
    @EnvironmentObject private var progress: ReadingProgress

    var body: some View {
        ScrollView {
            if let tonight = list.tonight {
                NightView(night: tonight, isTonight: true)
            } else if list.lineup != nil {
                NightOff()
            } else {
                Text("The reading list hasn't arrived yet. Check you're online.")
                    .font(.lamp(18))
                    .foregroundStyle(Palette.muted)
                    .padding(60)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await list.refresh() }
    }
}

/// Fridays and Saturdays, or after the list runs out.
private struct NightOff: View {
    @EnvironmentObject private var list: ReadingList
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var progress: ReadingProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NO READING TONIGHT").font(.label(12)).tracking(1.8).foregroundStyle(Palette.ember)
                Text("A night off.")
                    .font(.lamp(46, .medium))
                    .foregroundStyle(Palette.ink)
                if let next = list.nextNight {
                    Text("The next night is \(GoodnightView.dayName(next.day)): \(next.headline)\(next.field.map { ", \($0.lowercased())" } ?? "").")
                        .font(.lamp(19))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("You've reached the end of the list for now. New nights will appear here as soon as they're added.")
                        .font(.lamp(19))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !list.unfinished.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CATCH UP IF YOU LIKE").font(.label(11)).tracking(1.6).foregroundStyle(Palette.faint)
                    ForEach(list.unfinished) { night in
                        Button { router.read(night, from: nil) } label: {
                            NightLine(night: night)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let next = list.nextNight {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OR READ AHEAD").font(.label(11)).tracking(1.6).foregroundStyle(Palette.faint)
                    Button { router.read(next, from: nil) } label: {
                        NightLine(night: next)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 60)
    }
}

/// A one-line summary of a night, used in lists.
struct NightLine: View {
    let night: Night
    @EnvironmentObject private var progress: ReadingProgress

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(Self.weekday(night.day)).font(.label(10)).tracking(1).foregroundStyle(Palette.ember)
                Text(Self.dayNumber(night.day)).font(.lamp(24, .medium)).foregroundStyle(Palette.ink)
            }
            .frame(width: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(night.headline).font(.lamp(19, .medium)).foregroundStyle(Palette.ink).lineLimit(2)
                Text("Night \(night.number)\(night.field.map { " · \($0)" } ?? "")")
                    .font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(night.pieces) { piece in
                    Circle().fill(progress.isDone(piece) ? Palette.ember : Palette.line).frame(width: 6, height: 6)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1))
        .contentShape(Rectangle())
    }

    static func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    static func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "d"
        return f.string(from: date)
    }
}

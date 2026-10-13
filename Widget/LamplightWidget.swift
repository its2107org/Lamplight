import WidgetKit
import SwiftUI

struct TonightEntry: TimelineEntry {
    let date: Date
    let night: Night?
    let next: Night?
}

struct TonightProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonightEntry {
        let lineup = LineupSource.local()
        return TonightEntry(date: Date(), night: lineup?.nights.first, next: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) {
        let lineup = LineupSource.local()
        completion(TonightEntry(date: Date(), night: lineup?.tonight() ?? lineup?.nights.first, next: lineup?.next()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        Task {
            let lineup = await LineupSource.fetch() ?? LineupSource.local()
            let now = Date()
            // Change over at 4am, when the evening is properly over.
            let calendar = Calendar.current
            let fourAM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: now) ?? now
            let changeover = fourAM > now ? fourAM : calendar.date(byAdding: .day, value: 1, to: fourAM)!
            var entries = [TonightEntry(date: now, night: lineup?.tonight(at: now), next: lineup?.next(after: now))]
            let later = changeover.addingTimeInterval(60)
            entries.append(TonightEntry(date: later, night: lineup?.tonight(at: later), next: lineup?.next(after: later)))
            let refresh = calendar.date(byAdding: .hour, value: 6, to: now) ?? later
            completion(Timeline(entries: entries, policy: .after(min(refresh, later.addingTimeInterval(3600)))))
        }
    }
}

struct TonightWidgetView: View {
    let entry: TonightEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let night = entry.night {
                    Label("Tonight: \(night.headline)", systemImage: "moon.stars")
                } else {
                    Label("No reading tonight", systemImage: "moon")
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label(entry.night == nil ? "Night off" : "Tonight", systemImage: "moon.stars.fill")
                        .font(.caption2.weight(.semibold))
                    Text(entry.night?.headline ?? entry.next.map { "Next: \($0.headline)" } ?? "Lamplight")
                        .font(.system(.headline, design: .serif))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                full
            }
        }
        .widgetURL(URL(string: "lamplight://tonight"))
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                Text(entry.night == nil ? "NIGHT OFF" : "TONIGHT")
                    .tracking(1.4)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.ember)

            if let night = entry.night {
                Text(night.headline)
                    .font(.lamp(family == .systemSmall ? 19 : 24, .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(family == .systemSmall ? 3 : 2)
                    .minimumScaleFactor(0.8)
                if family != .systemSmall, let learn = night.learn {
                    Text(learn)
                        .font(.lamp(14))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(family == .systemLarge || family == .systemExtraLarge ? 4 : 2)
                }
                if family == .systemLarge || family == .systemExtraLarge {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(night.pieces) { piece in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(piece.kind.label.uppercased())
                                    .font(.system(size: 9, weight: .semibold)).tracking(1)
                                    .foregroundStyle(Palette.ember)
                                    .frame(width: 52, alignment: .leading)
                                Text(piece.title)
                                    .font(.lamp(14))
                                    .foregroundStyle(Palette.ink.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                Spacer(minLength: 0)
                Text(night.field.map { "\($0) · 5 pieces" } ?? "5 pieces")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
            } else {
                Text(entry.next.map { "Next: \($0.headline)" } ?? "Nothing on the list yet")
                    .font(.lamp(family == .systemSmall ? 18 : 22, .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Tonight", provider: TonightProvider()) { entry in
            TonightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Palette.raised, Palette.background], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Tonight's Reading")
        .description("Tonight's theme and what you'll learn.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LamplightWidgets: WidgetBundle {
    var body: some Widget {
        TonightWidget()
    }
}

import SwiftUI

/// Every night on the list, past and to come.
struct PlanView: View {
    @EnvironmentObject private var list: ReadingList
    @EnvironmentObject private var progress: ReadingProgress

    private var sections: [(String, [Night])] {
        guard let lineup = list.lineup else { return [] }
        let today = Lineup.readingDay()
        let tonight = lineup.nights.filter { Calendar.current.isDate($0.day, inSameDayAs: today) }
        let ahead = lineup.nights.filter { $0.day > today }
        let past = lineup.nights.filter { $0.day < today }.reversed()
        return [("Tonight", tonight), ("Coming up", ahead), ("Earlier", Array(past))].filter { !$0.1.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if let lineup = list.lineup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All nights").font(.lamp(40, .medium)).foregroundStyle(Palette.ink)
                        Text("\(progress.completedNights(in: lineup)) of \(lineup.nights.count) nights finished")
                            .font(.lamp(17)).foregroundStyle(Palette.muted)
                    }
                }
                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.0.uppercased()).font(.label(11)).tracking(1.6).foregroundStyle(Palette.faint)
                        ForEach(section.1) { night in
                            NavigationLink(value: night.number) { NightLine(night: night) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .background(Palette.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Int.self) { number in
            if let night = list.lineup?.night(number: number) {
                ScrollView {
                    NightView(night: night, isTonight: list.tonight?.number == number)
                }
                .background(Palette.background.ignoresSafeArea())
                .scrollIndicators(.hidden)
            }
        }
    }
}

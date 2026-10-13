import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: Router

    var body: some View {
        NavigationStack {
            TonightView()
                .background(Palette.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { router.showPlan = true } label: {
                            Label("All nights", systemImage: "calendar")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").font(.system(size: 13))
                            Text("Lamplight").font(.lamp(17, .semibold))
                        }
                        .foregroundStyle(Palette.glow)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { router.showSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Palette.background, for: .navigationBar)
                .navigationDestination(isPresented: $router.showPlan) { PlanView() }
        }
        .tint(Palette.ember)
        .background(Palette.background.ignoresSafeArea())
        .background(PageReaderAnchor().frame(width: 1, height: 1))
        .fullScreenCover(item: $router.reading) { request in
            ReaderView(night: request.night, start: request.start)
        }
        .sheet(isPresented: $router.showSettings) { SettingsView() }
    }
}

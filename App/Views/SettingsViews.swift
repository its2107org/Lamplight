import SwiftUI

/// Text size, font, colours and dimming, opened from the reader's "Aa" button.
struct AppearancePanel: View {
    @EnvironmentObject private var settings: ReaderSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 14) {
                    ForEach(PageTheme.allCases) { theme in
                        Button { settings.theme = theme } label: {
                            VStack(spacing: 8) {
                                Text("Aa")
                                    .font(.lamp(22, .medium))
                                    .foregroundStyle(theme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(theme.background))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(settings.theme == theme ? Palette.ember : Palette.line, lineWidth: settings.theme == theme ? 2 : 1))
                                Text(theme.name).font(.system(size: 13)).foregroundStyle(Palette.muted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 14) {
                    Image(systemName: "textformat.size.smaller").foregroundStyle(Palette.muted)
                    Slider(value: $settings.textSize, in: ReaderSettings.sizes, step: 1)
                    Image(systemName: "textformat.size.larger").foregroundStyle(Palette.muted)
                }

                HStack(spacing: 14) {
                    Image(systemName: "sun.min").foregroundStyle(Palette.muted)
                    Slider(value: Binding(get: { 0.75 - settings.dimmer }, set: { settings.dimmer = 0.75 - $0 }), in: 0...0.75)
                    Image(systemName: "sun.max").foregroundStyle(Palette.muted)
                }
                .accessibilityLabel("Brightness")

                VStack(spacing: 0) {
                    ForEach(PageFont.allCases) { font in
                        Button { settings.font = font } label: {
                            HStack {
                                Text(font.name).font(font.preview).foregroundStyle(Palette.ink)
                                Spacer()
                                if settings.font == font {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.ember)
                                }
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if font != PageFont.allCases.last {
                            Rectangle().fill(Palette.line).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.raised))
            }
            .padding(24)
        }
        .tint(Palette.ember)
        .preferredColorScheme(.dark)
    }
}

/// App settings: the wind-down reminder, reading look and the reading list.
struct SettingsView: View {
    @EnvironmentObject private var settings: ReaderSettings
    @EnvironmentObject private var list: ReadingList
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Wind-down reminder", isOn: Binding(get: { settings.reminderOn }, set: { on in
                        settings.reminderOn = on
                        Task {
                            if on, !(await Reminders.requestPermission()) {
                                settings.reminderOn = false
                                permissionDenied = true
                            }
                            await Reminders.reschedule()
                        }
                    }))
                    if settings.reminderOn {
                        DatePicker("Time", selection: Binding(get: { settings.reminderTime }, set: {
                            settings.reminderTime = $0
                            Task { await Reminders.reschedule() }
                        }), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Bedtime")
                } footer: {
                    Text(permissionDenied
                         ? "Reminders are switched off for Lamplight in the Settings app, under Notifications."
                         : "A quiet note on reading nights saying what's in store, so you can start winding down.")
                }

                Section {
                    Toggle("Dim further as it gets later", isOn: $settings.lateDimming)
                    Toggle("Keep the screen on while reading", isOn: $settings.keepAwake)
                    NavigationLink("Text and colours") {
                        AppearancePanel()
                            .background(Palette.surface.ignoresSafeArea())
                            .navigationTitle("Text and colours")
                    }
                } header: {
                    Text("Reading")
                } footer: {
                    Text("A dimmer screen matters more for sleep than its colour, so the page gets a touch darker after 10pm and again after 11pm. Leave the screen-on switch off if you might drift off mid-story.")
                }

                Section {
                    Button {
                        Task { await list.refresh(); await list.prepareAhead() }
                    } label: {
                        HStack {
                            Text("Check for new nights")
                            Spacer()
                            if list.checking { ProgressView() }
                        }
                    }
                    if let checked = list.lastChecked {
                        LabeledContent("Last checked", value: checked.formatted(date: .omitted, time: .shortened))
                    }
                    if let count = list.lineup?.nights.count {
                        LabeledContent("Nights on the list", value: "\(count)")
                    }
                } header: {
                    Text("Reading list")
                } footer: {
                    Text("New nights appear on their own. Each night's reading is downloaded ahead of time, so it's ready even without Wi-Fi.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Palette.ember)
        .preferredColorScheme(.dark)
    }
}

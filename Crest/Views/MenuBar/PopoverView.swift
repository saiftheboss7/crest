import SwiftUI
import AppKit

struct PopoverView: View {
    var clock: ClockService
    var calendarService: CalendarService
    var prayerTimeService: PrayerTimeService

    @AppStorage(AppSettingsKey.islamicModeEnabled) private var islamicModeEnabled = AppSettingsDefault.islamicModeEnabled
    @AppStorage(AppSettingsKey.settingsSelectedTab) private var settingsSelectedTab = AppSettingsDefault.settingsSelectedTab

    @Environment(\.openSettings) private var openSettingsAction

    @State private var selectedDate: Date? = nil

    private var showPrayers: Bool {
        islamicModeEnabled && !prayerTimeService.todayPrayers.isEmpty
    }

    private var showLocationEmptyState: Bool {
        islamicModeEnabled && prayerTimeService.todayPrayers.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekStripView(
                calendarService: calendarService,
                selectedDate: $selectedDate,
                hijriDateString: islamicModeEnabled ? prayerTimeService.hijriDateString : nil
            )

            Divider().opacity(0.5)

            EventListView(
                calendarService: calendarService,
                selectedDate: selectedDate
            )

            if showPrayers {
                // No divider — keeps the prayer block visually weightless, in
                // line with the "minimal, no borders" treatment.
                PrayerTimesView(prayerTimeService: prayerTimeService)
            } else if showLocationEmptyState {
                Divider().opacity(0.5)
                PrayerLocationEmptyStateView {
                    settingsSelectedTab = 2
                    openSettings()
                }
            }

            Divider().opacity(0.5)

            footer
        }
        .frame(width: 320)
        .modifier(GlassPopoverBackground())
    }

    private var footer: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings ⌘,")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit ⌘Q")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func openSettings() {
        openSettingsAction()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows where !window.title.isEmpty && window.title != "Item-0" {
                window.orderFrontRegardless()
            }
        }
    }
}

/// Applies Liquid Glass to the popover surface — the popover itself is a
/// transient floating *navigation panel*, which is exactly what the Liquid
/// Glass design language is for. Per the rule "glass cannot sample other
/// glass," we apply glass once here at the outer container and keep all
/// interior controls (chevrons, Today pill, countdown badge, footer buttons)
/// as solid translucent capsules. No `GlassEffectContainer` is needed inside
/// because we deliberately have a single glass surface.
///
/// On pre-macOS-26 SDKs we fall back to `.ultraThinMaterial` plus a thin
/// top-edge specular highlight to approximate the look — the call site stays
/// identical so the upgrade is automatic.
private struct GlassPopoverBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // `.clear` glass = high transparency, limited adaptation — more of
            // the backdrop bleeds through than `.regular` for a "looking-through-
            // glass" feel. The skill earmarks `.clear` for "media-rich backgrounds
            // where content is bold/bright"; the desktop behind a menu-bar
            // popover qualifies. Corner radius matches the macOS popover window.
            content
                .glassEffect(.clear, in: .rect(cornerRadius: 10))
        } else {
            // Material fallback for older SDKs / older OS.
            content
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        // Subtle top-edge specular highlight for "glass
                        // curvature" feel without affecting legibility.
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.06), location: 0.08),
                                .init(color: Color.clear, location: 0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                }
        }
    }
}

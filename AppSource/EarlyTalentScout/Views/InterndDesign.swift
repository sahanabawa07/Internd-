import SwiftUI
import AppKit

enum InterndPalette {
    static let ink = Color(red: 0.17, green: 0.13, blue: 0.16)
    static let peach = Color(red: 1.00, green: 0.90, blue: 0.85)
    static let blue = Color(red: 0.88, green: 0.93, blue: 1.00)
    static let pink = Color(red: 0.98, green: 0.88, blue: 0.92)
    static let lavender = Color(red: 0.91, green: 0.88, blue: 0.98)
    static let sage = Color(red: 0.89, green: 0.94, blue: 0.90)
}

struct WelcomeView: View {
    let begin: () -> Void

    var body: some View {
        ZStack {
            pastelBackdrop
            HStack(spacing: 58) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Internd")
                        .font(.system(size: 78, weight: .semibold, design: .serif))
                        .foregroundStyle(InterndPalette.ink)
                    Text("A holistic approach to applying to internships.")
                        .font(.system(size: 29, weight: .medium, design: .serif))
                        .foregroundStyle(InterndPalette.ink.opacity(0.82))
                        .frame(maxWidth: 430, alignment: .leading)
                        .padding(.top, 34)
                    Text("A calm place to plan applications, discover early-talent programs, and grow meaningful connections.")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 430, alignment: .leading)
                        .padding(.top, 18)
                    Button(action: begin) {
                        Label("Begin", systemImage: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 25)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(InterndPalette.ink)
                    .padding(.top, 32)
                }
                FloralLogoView()
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                    .shadow(color: .black.opacity(0.09), radius: 18, y: 10)
            }
            .padding(60)
        }
    }

    private var pastelBackdrop: some View {
        LinearGradient(colors: [InterndPalette.peach, InterndPalette.blue, InterndPalette.pink, InterndPalette.lavender], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct WorkspaceHomeView: View {
    let store: AppStore
    private let columns = [GridItem(.adaptive(minimum: 185), spacing: 16)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [InterndPalette.peach.opacity(0.62), InterndPalette.blue.opacity(0.64), InterndPalette.pink.opacity(0.68), InterndPalette.lavender.opacity(0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your career garden")
                                .font(.system(size: 42, weight: .semibold, design: .serif))
                            Text("Choose a space to tend today.")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.selection = .today
                        } label: {
                            Text("\(nextActions) next action\(nextActions == 1 ? "" : "s")")
                        }
                        .buttonStyle(.plain)
                            .font(.system(size: 18, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.58), in: Capsule())
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(WorkspaceSection.allCases) { section in
                            WorkspaceTile(section: section) {
                                store.selection = section
                            }
                        }
                    }
                }
                .padding(36)
                .frame(maxWidth: 1_050, alignment: .leading)
            }
        }
    }

    private var nextActions: Int {
        max(1, store.applications.filter { !$0.deadline.isEmpty }.count + (store.relationships.isEmpty ? 1 : 0))
    }
}

struct DetailPageShell<Content: View>: View {
    let section: WorkspaceSection
    let returnToGarden: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            LinearGradient(colors: [InterndPalette.peach.opacity(0.65), InterndPalette.blue.opacity(0.62), InterndPalette.pink.opacity(0.65), InterndPalette.lavender.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Button(action: returnToGarden) {
                    Label("All spaces", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(InterndPalette.ink.opacity(0.78))
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.rawValue)
                            .font(.system(size: 39, weight: .semibold, design: .serif))
                        Text(pageNote)
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: section.icon)
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(InterndPalette.ink.opacity(0.76))
                        .frame(width: 54, height: 54)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .padding(.bottom, 2)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
            }
            .padding(32)
            .frame(maxWidth: 1_080, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var pageNote: String {
        switch section {
        case .today: "Small steps, steady momentum."
        case .profile: "The details that make recommendations feel like you."
        case .research: "Programs with a real reason to apply."
        case .network: "Connections grow through thoughtful follow-up."
        case .tracker: "Keep every deadline and detail in one place."
        case .tailor: "Shape each application around the opportunity."
        case .outreach: "Write messages that feel personal and clear."
        case .skills: "Build the strengths your goals call for."
        case .companies: "Learn before you reach out or apply."
        case .quality: "Check your materials before you submit."
        case .interview: "Practice stories that show your strengths."
        case .insights: "Notice the progress you are making."
        }
    }
}

private struct WorkspaceTile: View {
    let section: WorkspaceSection
    let action: () -> Void

    private var subtitle: String {
        switch section {
        case .today: "Your next steps"
        case .profile: "Your story and goals"
        case .research: "Find programs"
        case .network: "Warm connections"
        case .tracker: "Dates and details"
        case .tailor: "Role-ready materials"
        case .outreach: "Thoughtful drafts"
        case .skills: "Grow with purpose"
        case .companies: "Know where you apply"
        case .quality: "Make every detail count"
        case .interview: "Practice your stories"
        case .insights: "See your momentum"
        }
    }

    private var color: Color {
        let colors = [InterndPalette.pink, InterndPalette.sage, InterndPalette.lavender, InterndPalette.peach, InterndPalette.blue]
        return colors[WorkspaceSection.allCases.firstIndex(of: section)! % colors.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: section.icon)
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(InterndPalette.ink.opacity(0.82))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: InterndPalette.ink.opacity(0.08), radius: 6, y: 3)
                Spacer(minLength: 2)
                Text(section.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(InterndPalette.ink)
                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(InterndPalette.ink.opacity(0.67))
                    .lineLimit(1)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
            .background(color.opacity(0.9), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(.white.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .accessibilityHint(subtitle)
    }
}

private struct FloralLogoView: View {
    var body: some View {
        if let url = Bundle.module.url(forResource: "InterndIcon", withExtension: "png", subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "textformat")
                .font(.system(size: 90, weight: .bold, design: .serif))
                .foregroundStyle(InterndPalette.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(InterndPalette.pink)
        }
    }
}

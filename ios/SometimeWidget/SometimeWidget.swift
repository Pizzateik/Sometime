import WidgetKit
import SwiftUI
import AppIntents
import CoreText

enum WidgetStore {
    static let group = "group.de.eik.todoApp"
    static var data: WidgetData {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget.json"),
              let bytes = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(WidgetData.self, from: bytes) else { return WidgetData(language: "en", mode: "system", spaces: []) }
        return value
    }
    static func link(space: String, task: String? = nil, category: String = "today", create: Bool = false) -> URL {
        var url = URLComponents()
        url.scheme = "sometime"
        url.host = "widget"
        url.queryItems = [URLQueryItem(name: "space", value: space), URLQueryItem(name: "category", value: category), URLQueryItem(name: "create", value: String(create))]
        if let task { url.queryItems?.append(URLQueryItem(name: "task", value: task)) }
        return url.url!
    }
}
struct WidgetData: Decodable {
    let language: String
    let mode: String
    let spaces: [WidgetSpace]
}
struct WidgetSpace: Decodable {
    let id: String
    let name: String
    let tasks: [WidgetTask]
}
struct WidgetTask: Decodable, Identifiable {
    let id: String
    let title: String
    let category: String
    let available: Double?
    let minutes: Int?
}

private struct WidgetCopy {
    let openTask: (String) -> String
    let createTask: String
    let emptySpace: String
    let emptyTasks: String
    let categoryTitles: [String: String]
}

private func widgetCopy(for languageTag: String) -> WidgetCopy {
    let language = languageTag.lowercased()
    if language.hasPrefix("de") {
        return WidgetCopy(openTask: { "Aufgabe öffnen: \($0)" }, createTask: "Aufgabe erstellen", emptySpace: "Space auswählen", emptyTasks: "Keine Aufgaben", categoryTitles: ["today": "HEUTE", "soon": "DEMNÄCHST", "someday": "IRGENDWANN"])
    }
    if language.hasPrefix("es") {
        return WidgetCopy(openTask: { "Abrir tarea: \($0)" }, createTask: "Crear tarea", emptySpace: "Seleccionar Space", emptyTasks: "No hay tareas", categoryTitles: ["today": "HOY", "soon": "PRONTO", "someday": "ALGÚN DÍA"])
    }
    if language.hasPrefix("pt-br") || language == "pt" {
        return WidgetCopy(openTask: { "Abrir tarefa: \($0)" }, createTask: "Criar tarefa", emptySpace: "Selecionar Space", emptyTasks: "Nenhuma tarefa", categoryTitles: ["today": "HOJE", "soon": "EM BREVE", "someday": "ALGUM DIA"])
    }
    if language.hasPrefix("fr") {
        return WidgetCopy(openTask: { "Ouvrir la tâche : \($0)" }, createTask: "Créer une tâche", emptySpace: "Choisir un Space", emptyTasks: "Aucune tâche", categoryTitles: ["today": "AUJOURD’HUI", "soon": "BIENTÔT", "someday": "UN JOUR"])
    }
    if language.hasPrefix("ja") {
        return WidgetCopy(openTask: { "タスクを開く: \($0)" }, createTask: "タスクを作成", emptySpace: "Spaceを選択", emptyTasks: "タスクはありません", categoryTitles: ["today": "今日", "soon": "すぐに", "someday": "いつか"])
    }
    return WidgetCopy(openTask: { "Open task: \($0)" }, createTask: "Create task", emptySpace: "Choose a space", emptyTasks: "No tasks", categoryTitles: ["today": "TODAY", "soon": "SOON", "someday": "SOMETIME"])
}
struct SpaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Space"
    static var defaultQuery = SpaceQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct SpaceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SpaceEntity] {
        WidgetStore.data.spaces.filter { identifiers.contains($0.id) }.map { SpaceEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [SpaceEntity] {
        WidgetStore.data.spaces.map { SpaceEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> SpaceEntity? {
        WidgetStore.data.spaces.first.map { SpaceEntity(id: $0.id, name: $0.name) }
    }
}
enum TaskCategory: String, AppEnum {
    case today, soon, someday, all
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var caseDisplayRepresentations: [TaskCategory: DisplayRepresentation] = [.today: "Today", .soon: "Soon", .someday: "Sometime", .all: "All"]
}
struct WidgetOptions: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Sometime widget"
    static var description = IntentDescription("Choose a space and a category.")
    @Parameter(title: "Space") var space: SpaceEntity?
    @Parameter(title: "Category", default: .today) var category: TaskCategory
}
struct Entry: TimelineEntry {
    let date: Date
    let options: WidgetOptions
    let data: WidgetData
}
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), options: WidgetOptions(), data: WidgetStore.data) }
    func snapshot(for configuration: WidgetOptions, in context: Context) async -> Entry { Entry(date: Date(), options: configuration, data: WidgetStore.data) }
    func timeline(for configuration: WidgetOptions, in context: Context) async -> Timeline<Entry> {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        let data = WidgetStore.data
        let nextAvailability = data.spaces.flatMap(\.tasks).compactMap(\.available).map { Date(timeIntervalSince1970: $0 / 1000) }.filter { $0 > now }.min()
        let refresh = min(midnight, nextAvailability ?? midnight)
        return Timeline(entries: [Entry(date: now, options: configuration, data: data), Entry(date: refresh, options: configuration, data: data)], policy: .after(refresh))
    }
}
struct SometimeWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var systemScheme
    var copy: WidgetCopy { widgetCopy(for: entry.data.language) }
    var dark: Bool { entry.data.mode == "dark" || (entry.data.mode == "system" && systemScheme == .dark) }
    var ink: Color { dark ? .white : .black }
    var space: WidgetSpace? {
        if let selected = entry.options.space,
           let matching = entry.data.spaces.first(where: { $0.id == selected.id }) {
            return matching
        }
        return entry.data.spaces.first
    }
    var spaceID: String { space?.id ?? entry.data.spaces.first?.id ?? "default-space" }
    var tasks: [WidgetTask] {
        (space?.tasks ?? []).filter { ($0.available ?? 0) <= entry.date.timeIntervalSince1970 * 1000 && (entry.options.category == .all || $0.category == entry.options.category.rawValue) }
    }
    func title(_ group: String) -> String {
        copy.categoryTitles[group] ?? group.uppercased()
    }
    func group(_ category: String, limit: Int) -> some View {
        let items = Array(tasks.filter { $0.category == category }.prefix(limit))
        return VStack(alignment: .leading, spacing: 7) {
            if !items.isEmpty {
                Text(title(category)).font(.custom("Geist", size: 10).weight(.semibold)).foregroundStyle(ink.opacity(0.6))
                ForEach(items) { task in
                    Link(destination: WidgetStore.link(space: spaceID, task: task.id, category: category)) {
                        HStack(spacing: 7) {
                            Text("○").accessibilityHidden(true)
                            Text(task.title).lineLimit(1)
                            Spacer(minLength: 0)
                            if family == .systemMedium, let minutes = task.minutes {
                                Text(String(format: "%02d:%02d", minutes / 60, minutes % 60)).font(.custom("Geist", size: 10)).foregroundStyle(ink.opacity(0.6))
                            }
                        }.font(.custom("Geist", size: 12).weight(.medium)).foregroundStyle(ink)
                    }.accessibilityLabel(copy.openTask(task.title))
                }
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(space?.name ?? "Sometime").lineLimit(1).font(.custom("Geist", size: 16).weight(.semibold))
                Spacer()

            }.foregroundStyle(ink)
            if tasks.isEmpty {
                Text(space == nil ? copy.emptySpace : copy.emptyTasks)
                    .font(.custom("Geist", size: 12)).foregroundStyle(ink.opacity(0.6))
            } else if family == .systemMedium && entry.options.category == .all {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) { group("today", limit: 2) }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 10) { group("soon", limit: 1); group("someday", limit: 1) }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if entry.options.category == .all {
                ForEach(["today", "soon", "someday"], id: \.self) { group($0, limit: 1) }
            } else {
                group(entry.options.category.rawValue, limit: family == .systemSmall ? 3 : 2)
            }
            Spacer(minLength: 0)
            if family == .systemMedium {
                HStack {
                    Spacer()
                    Link(destination: WidgetStore.link(space: spaceID, category: entry.options.category.rawValue, create: true)) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(dark ? Color.black : Color.white)
                            .frame(width: 36, height: 36)
                            .background(ink, in: RoundedRectangle(cornerRadius: 10))
                    }.accessibilityLabel(copy.createTask)
                }
            }
        }
        .containerBackground(dark ? Color(white: 0.07) : Color(red: 0.98, green: 0.98, blue: 0.97), for: .widget)
        .widgetURL(WidgetStore.link(space: spaceID, task: tasks.first?.id, category: entry.options.category.rawValue))
    }
}
@main
struct SometimeWidget: Widget {
    init() {
        if let url = Bundle.main.url(forResource: "Geist-Variable", withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SometimeWidget", intent: WidgetOptions.self, provider: Provider()) { SometimeWidgetView(entry: $0) }
            .configurationDisplayName("Sometime")
            .description("Your tasks, on this device.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

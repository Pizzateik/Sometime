import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var notifications: TaskNotifications?
  private var sharedEngine: FlutterEngine?
  private var widgets: SometimeWidgetBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The app and notification actions share one controller and one storage writer.
  func taskEngine() -> FlutterEngine {
    if let engine = sharedEngine { return engine }
    let engine = FlutterEngine(name: "sometime", project: nil, allowHeadlessExecution: true)
    sharedEngine = engine
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    notifications = TaskNotifications(messenger: engine.binaryMessenger)
    widgets = SometimeWidgetBridge(messenger: engine.binaryMessenger)
    return engine
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound, .list])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    let info = response.notification.request.content.userInfo
    guard let task = info["task"] as? String, let space = info["space"] as? String else {
      completionHandler()
      return
    }
    let action = response.actionIdentifier == "complete" ? "complete" : "open"
    TaskNotifications.enqueue(task: task, space: space, action: action)
    _ = taskEngine()
    notifications?.wake(completion: completionHandler)
  }
}

final class SometimeWidgetBridge {
  private static var launch: [String: Any]?
  private static var current: SometimeWidgetBridge?
  private let channel: FlutterMethodChannel
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "sometime/widgets", binaryMessenger: messenger)
    Self.current = self
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "sync":
        guard let source = call.arguments as? String,
          let bytes = source.data(using: .utf8),
          let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.de.eik.todoApp") else {
          result(FlutterError(code: "storage", message: "The widget storage is not available.", details: nil))
          return
        }
        do {
          try bytes.write(to: directory.appendingPathComponent("widget.json"), options: .atomic)
          WidgetCenter.shared.reloadTimelines(ofKind: "SometimeWidget")
          result(nil)
        } catch { result(FlutterError(code: "storage", message: "The widget data could not be saved.", details: nil)) }
      case "launch":
        result(Self.launch)
        Self.launch = nil
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  static func open(_ url: URL) {
    guard url.scheme == "sometime", url.host == "widget", let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
    var target: [String: Any] = [:]
    for item in components.queryItems ?? [] {
      if ["space", "task", "category"].contains(item.name) { target[item.name] = item.value }
      if item.name == "create" { target[item.name] = item.value == "true" }
    }
    launch = target
    current?.channel.invokeMethod("open", arguments: nil)
  }
}

// Keep the bridge in this file so the existing Runner target compiles it.
final class TaskNotifications {
  private let channel: FlutterMethodChannel
  private let center = UNUserNotificationCenter.current()
  private var completions: [() -> Void] = []
  private static let eventKey = "sometime.notification.events"

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "sometime/notifications", binaryMessenger: messenger)
    let complete = UNNotificationAction(identifier: "complete", title: "Complete", options: [])
    center.setNotificationCategories([UNNotificationCategory(identifier: "task", actions: [complete], intentIdentifiers: [])])
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "permission":
        self.center.getNotificationSettings { settings in
          if settings.authorizationStatus == .notDetermined {
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, error in
              DispatchQueue.main.async { result(allowed && error == nil) }
            }
          } else {
            DispatchQueue.main.async { result(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) }
          }
        }
      case "settings":
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        result(nil)
      case "events": result(Self.events())
      case "ack":
        let remaining = Self.events().filter { ($0["id"] as? String) != call.arguments as? String }
        UserDefaults.standard.set(remaining, forKey: Self.eventKey)

        result(nil)
      case "sync":
        if !Self.events().isEmpty { result(["retry": true]); return }
        self.sync(call.arguments as? [[String: Any]] ?? [], result: result)
      case "removeSpace":
        guard let space = call.arguments as? String else { result(nil); return }
        self.removeSpace(space, result: result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  static func events() -> [[String: Any]] {
    UserDefaults.standard.array(forKey: eventKey) as? [[String: Any]] ?? []
  }
  static func enqueue(task: String, space: String, action: String) {
    var queue = events()
    queue.append(["id": UUID().uuidString, "task": task, "space": space, "action": action])
    UserDefaults.standard.set(queue, forKey: eventKey)
  }
  private func removeSpace(_ space: String, result: @escaping FlutterResult) {
    let remaining = Self.events().filter { ($0["space"] as? String) != space }
    UserDefaults.standard.set(remaining, forKey: Self.eventKey)
    center.getDeliveredNotifications { delivered in
      let deliveredIDs = delivered
        .filter { ($0.request.content.userInfo["space"] as? String) == space }
        .map { $0.request.identifier }
      self.center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
      self.center.getPendingNotificationRequests { pending in
        let pendingIDs = pending
          .filter { ($0.content.userInfo["space"] as? String) == space }
          .map { $0.identifier }
        self.center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        DispatchQueue.main.async { result(nil) }
      }
    }
  }
  func wake(completion: @escaping () -> Void) {
    completions.append(completion)
    channel.invokeMethod("events", arguments: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
      self?.completions.forEach { $0() }
      self?.completions.removeAll()
    }
  }

  private func sync(_ specs: [[String: Any]], result: @escaping FlutterResult) {
    let identifiers = Set(specs.compactMap { $0["id"] as? String })
    center.getDeliveredNotifications { delivered in
      self.center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { !identifiers.contains($0) })
    }
    center.getPendingNotificationRequests { pending in
      self.center.removePendingNotificationRequests(withIdentifiers: pending.map { $0.identifier })
      self.center.getNotificationSettings { settings in
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let future = specs.filter { (($0["at"] as? NSNumber)?.doubleValue ?? 0) > Date().timeIntervalSince1970 * 1000 }
          .sorted { (($0["at"] as? NSNumber)?.doubleValue ?? 0) < (($1["at"] as? NSNumber)?.doubleValue ?? 0) }
        let group = DispatchGroup()
        var failed = false
        let lock = NSLock()
        if allowed {
          for spec in future.prefix(64) {
            guard let id = spec["id"] as? String, let at = spec["at"] as? NSNumber else { continue }
            let content = UNMutableNotificationContent()
            content.title = spec["title"] as? String ?? "Sometime"
            content.categoryIdentifier = "task"
            content.sound = .default
            content.userInfo = ["task": id, "space": spec["space"] as? String ?? ""]
            let date = (spec["date"] as? [Int]) ?? []
            let day = date.count == 3 ? "\(date[2]).\(date[1]).\(date[0])" : ""
            let fallback: String
            if let minutes = spec["minutes"] as? Int {
              fallback = "\(day) · " + String(format: "%02d:%02d", minutes / 60, minutes % 60)
            } else { fallback = day }
            let description = (spec["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            content.body = description.isEmpty ? fallback : description
            // Calendar components retain local wall time after a timezone change.
            let fireDate = Date(timeIntervalSince1970: at.doubleValue / 1000)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            group.enter()
            self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
              if error != nil { lock.lock(); failed = true; lock.unlock() }
              group.leave()
            }
          }
        }
        group.notify(queue: .main) {
          var response: [String: Any] = ["allowed": allowed]
          if failed { response["warning"] = "Some reminders could not be scheduled." }
          else if future.count > 64 { response["warning"] = "iOS allows 64 pending reminders. Open Sometime to schedule later reminders." }
          result(response)
          self.completions.forEach { $0() }
          self.completions.removeAll()
        }
      }
    }
  }
}




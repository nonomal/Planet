//
//  PlanetAppDelegate.swift
//  Planet
//
//  Created by Kai on 5/24/23.
//

import SwiftUI
import UserNotifications


class PlanetAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = PlanetAppDelegate()

    var templateWindowController: TBWindowController?
    var downloadsWindowController: PlanetDownloadsWindowController?
    var publishedFoldersDashboardWindowController: PFDashboardWindowController?
    var keyManagerWindowController: PlanetKeyManagerWindowController?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    // use AppDelegate lifecycle since View.onOpenURL does not work
    // Reference: https://developer.apple.com/forums/thread/673822
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if url.absoluteString.hasPrefix("planet://") {
            let link = url.absoluteString.replacingOccurrences(of: "planet://", with: "")
            Task { @MainActor in
                let planet = try await FollowingPlanetModel.follow(link: link)
                PlanetStore.shared.followingPlanets.insert(planet, at: 0)
                PlanetStore.shared.selectedView = .followingPlanet(planet)
            }
        } else if url.lastPathComponent.hasSuffix(".planet") {
            Task { @MainActor in
                do {
                    let planet = try MyPlanetModel.importBackup(from: url)
                    PlanetStore.shared.myPlanets.insert(planet, at: 0)
                    PlanetStore.shared.selectedView = .myPlanet(planet)
                } catch {
                    PlanetStore.shared.isShowingAlert = true
                    PlanetStore.shared.alertTitle = "Failed to Import Planet"
                    PlanetStore.shared.alertMessage = error.localizedDescription
                }
            }
        } else if url.lastPathComponent.hasSuffix(".article") {
            Task { @MainActor in
                do {
                    try await MyArticleModel.importArticles(fromURLs: urls)
                } catch {
                    debugPrint("failed to import articles: \(error)")
                    PlanetStore.shared.isShowingAlert = true
                    PlanetStore.shared.alertTitle = "Failed to Import Articles"
                    switch error {
                    case PlanetError.ImportPlanetArticlePublishingError:
                        PlanetStore.shared.alertMessage = "Planet is in publishing progress, please try again later."
                    default:
                        PlanetStore.shared.alertMessage = error.localizedDescription
                    }
                }
            }
        } else {
            createQuickShareWindow(forFiles: urls)
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        debugPrint("applicationWillBecomeActive")
        // TODO: If Writer is open, then the main window should not always get focus
        if let windows = (notification.object as? NSApplication)?.windows {
            var i = 0
            for window in windows where window.className == "SwiftUI.AppKitWindow" {
                debugPrint("Planet window: \(window)")
                debugPrint("window.isMainWindow: \(window.isMainWindow)")
                debugPrint("window.isMiniaturized: \(window.isMiniaturized)")
                if window.isMiniaturized {
                    if i == 0 {
                        window.makeKeyAndOrderFront(self)
                    } else {
                        window.deminiaturize(self)
                    }
                }
                i = i + 1
            }
            // See also: https://github.com/tact/public/issues/31
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotification()

        let saver = Saver.shared
        if saver.isMigrationNeeded() {
            Task { @MainActor in
                PlanetStore.shared.isMigrating = true
            }
            var migrationErrors: Int = 0
            migrationErrors = migrationErrors + saver.savePlanets()
            migrationErrors = migrationErrors + saver.migratePublic()
            migrationErrors = migrationErrors + saver.migrateTemplates()
            if migrationErrors == 0 {
                saver.setMigrationDoneFlag(flag: true)
                Task { @MainActor in
                    try PlanetStore.shared.load()
                    try TemplateStore.shared.load()
                }
            }
            Task { @MainActor in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                PlanetStore.shared.isMigrating = false
            }
        }

        PlanetUpdater.shared.checkForUpdatesInBackground()

        // Connect Wallet V2
        if let wc2Enabled: Bool = Bundle.main.object(forInfoDictionaryKey: "WALLETCONNECTV2_ENABLED") as? Bool, wc2Enabled == true {
            do {
                try WalletManager.shared.setupV2()
            } catch {
                debugPrint("WalletConnect 2.0 Failed to prepare the connection: \(error)")
            }
        }

        // Aggregate after app started for 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            Task.detached(priority: .background) {
                await PlanetStore.shared.aggregate()
            }
        }

        // Notify API server if system is going to sleep / awake
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
            if UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
                Task { @MainActor in
                    PlanetAPIController.shared.pauseServerForSleep()
                }
            }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            if UserDefaults.standard.bool(forKey: .settingsAPIEnabled) {
                Task.detached(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    Task { @MainActor in
                        PlanetAPIController.shared.startServer()
                    }
                }
            }
        }

        // Web app updater
        Task.detached(priority: .background) {
            await WebAppUpdater.shared.updateWebApp()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return PlanetStatusManager.shared.reply()
    }
}

// MARK: - User Notifications

extension PlanetAppDelegate: UNUserNotificationCenterDelegate {
    func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            debugPrint("Current notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .notDetermined else { return }
            if settings.alertSetting == .disabled || settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .badge]) { _, _ in
                }
            } else {
                center.delegate = self
                let readArticleCategory = UNNotificationCategory(identifier: .readArticleAlert, actions: [], intentIdentifiers: [], options: [])
                let showPlanetCategory = UNNotificationCategory(identifier: .showPlanetAlert, actions: [], intentIdentifiers: [], options: [])
                center.setNotificationCategories([readArticleCategory, showPlanetCategory])
            }
        }
    }

    func processNotification(_ response: UNNotificationResponse) {
        if response.actionIdentifier != UNNotificationDefaultActionIdentifier {
            return
        }
        switch response.notification.request.content.categoryIdentifier {
            case .readArticleAlert:
                Task { @MainActor in
                    let articleId = response.notification.request.identifier
                    for following in PlanetStore.shared.followingPlanets {
                        if let article = following.articles.first(where: { $0.id.uuidString == articleId }) {
                            PlanetStore.shared.selectedView = .followingPlanet(following)
                            PlanetStore.shared.refreshSelectedArticles()
                            Task { @MainActor in
                                PlanetStore.shared.selectedArticle = article
                            }
                            NSWorkspace.shared.open(URL(string: "planet://")!)
                            return
                        }
                    }
                }
            case .showPlanetAlert:
                Task { @MainActor in
                    let planetId = response.notification.request.identifier
                    if let following = PlanetStore.shared.followingPlanets.first(where: { $0.id.uuidString == planetId }) {
                        PlanetStore.shared.selectedView = .followingPlanet(following)
                        NSWorkspace.shared.open(URL(string: "planet://")!)
                    }
                }
            default:
                break
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge])
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        processNotification(response)
        completionHandler()
    }
}

// MARK: - Window Controllers

extension PlanetAppDelegate {
    func openDownloadsWindow() {
        if downloadsWindowController == nil {
            downloadsWindowController = PlanetDownloadsWindowController()
        }
        downloadsWindowController?.showWindow(nil)
    }

    func openTemplateWindow() {
        if templateWindowController == nil {
            templateWindowController = TBWindowController()
        }
        templateWindowController?.showWindow(nil)
    }

    func openPublishedFoldersDashboardWindow() {
        if publishedFoldersDashboardWindowController == nil {
            publishedFoldersDashboardWindowController = PFDashboardWindowController()
        }
        publishedFoldersDashboardWindowController?.showWindow(nil)
    }

    func openKeyManagerWindow() {
        if keyManagerWindowController == nil {
            keyManagerWindowController = PlanetKeyManagerWindowController()
        }
        keyManagerWindowController?.showWindow(nil)
    }

    func createQuickShareWindow(forFiles files: [URL]) {
        guard files.count > 0 else { return }
        Task { @MainActor in
            do {
                try PlanetQuickShareViewModel.shared.prepareFiles(files)
                PlanetStore.shared.isQuickSharing = true
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Create Post"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

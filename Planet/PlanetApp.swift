//
//  PlanetApp.swift
//  Planet
//
//  Created by Kai on 2/15/22.
//

import SwiftUI
import Sparkle


@main
struct PlanetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var planetStore = PlanetStore.shared
    @StateObject var templateStore = TemplateBrowserStore.shared
    @Environment(\.openURL) private var openURL

    var body: some Scene {
        WindowGroup {
            PlanetMainView()
                .environmentObject(planetStore)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "Planet"), allowing: Set(arrayLiteral: "Planet"))
        }
        .windowToolbarStyle(.automatic)
        .windowStyle(.titleBar)
        .handlesExternalEvents(matching: Set(arrayLiteral: "Planet"))
        .commands {
            CommandGroup(replacing: .newItem) {
            }
            CommandMenu("Tools") {
                Button {
                    openURL(URL(string: "planet://Template")!)
                } label: {
                    Text("Template Browser")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button {
                    planetStore.publishMyPlanets()
                } label: {
                    Text("Publish My Planets")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button {
                    planetStore.updateFollowingPlanets()
                } label: {
                    Text("Update Following Planets")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button {
                    planetStore.isImportingPlanet = true
                } label: {
                    Text("Import Planet")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                // TODO: move to my planet context menu
                Button {
                } label: {
                    Text("Export Planet")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button {
                    SUUpdater.shared().checkForUpdates(NSButton())
                } label: {
                    Text("Check for Updates")
                }
            }
            SidebarCommands()
        }

        WindowGroup("Planet Templates") {
            TemplateBrowserView()
                .environmentObject(templateStore)
                .frame(minWidth: 720, minHeight: 480)
                .handlesExternalEvents(
                    preferring: Set(arrayLiteral: "Template"),
                    allowing: Set(arrayLiteral: "Template")
                )
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "Template"))
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    // use AppDelegate lifecycle since View.onOpenURL does not work
    // Reference: https://developer.apple.com/forums/thread/673822
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if url.absoluteString.hasPrefix("planet://") {
            let link = url.absoluteString.replacingOccurrences(of: "planet://", with: "")
            Task {
                let followingPlanet = try await FollowingPlanetModel.follow(link: link)
                PlanetStore.shared.followingPlanets.insert(followingPlanet, at: 0)
            }
        } else if url.lastPathComponent.hasSuffix(".planet") {
            // TODO: import planet
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // let saver = Saver.shared
        // saver.savePlanets()
        // saver.migratePublic()
        TemplateBrowserStore.shared.loadTemplates()

        if let lastVisitedPlanetID = UserDefaults.standard.string(forKey: "LastVisitedPlanetID") {
            // TODO
        }

        SUUpdater.shared().checkForUpdatesInBackground()

        // let saver = Saver.shared
        // saver.savePlanets()
        // saver.migratePublic()
        // saver.migrateTemplates()


    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task.init {
            try PlanetStore.shared.save()
            await IPFSDaemon.shared.shutdownDaemon()
            await NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

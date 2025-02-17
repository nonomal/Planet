//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI

struct PlanetSidebarView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject var ipfsState = IPFSState.shared

    let timer1m = Timer.publish(every: 60, on: .current, in: .common).autoconnect()
    let timer3m = Timer.publish(every: 180, on: .current, in: .common).autoconnect()
    let timer5m = Timer.publish(every: 300, on: .current, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if planetStore.walletAddress.count > 0 {
                AccountBadgeView(walletAddress: planetStore.walletAddress)
                Divider()
            }

            List(selection: $planetStore.selectedView) {
                Section(header: Text("Smart Feeds")) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .resizable()
                            .foregroundColor(Color.orange)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Today")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .badge(planetStore.totalTodayCount)
                    .tag(PlanetDetailViewType.today)

                    HStack(spacing: 4) {
                        Image(systemName: "circle.inset.filled")
                            .resizable()
                            .foregroundColor(Color.blue)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Unread")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .badge(planetStore.totalUnreadCount)
                    .tag(PlanetDetailViewType.unread)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 18, height: 18)
                            .padding(.all, 2)
                        Text("Starred")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .badge(planetStore.totalStarredCount)
                    .tag(PlanetDetailViewType.starred)
                }

                Section(header: Text("My Planets")) {
                    ForEach(planetStore.myPlanets) { planet in
                        HStack {
                            MyPlanetSidebarItem(planet: planet)
                        }.tag(PlanetDetailViewType.myPlanet(planet))
                    }
                    .onMove { (indexes, dest) in
                        withAnimation {
                            planetStore.moveMyPlanets(fromOffsets: indexes, toOffset: dest)
                        }
                    }
                }

                Section(header: Text("Following Planets")) {
                    ForEach(planetStore.followingPlanets) { planet in
                        HStack {
                            FollowingPlanetSidebarItem(planet: planet)
                        }.tag(PlanetDetailViewType.followingPlanet(planet))
                    }
                    .onMove { (indexes, dest) in
                        withAnimation {
                            planetStore.moveFollowingPlanets(fromOffsets: indexes, toOffset: dest)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 6) {
                if ipfsState.isOperating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Spacer()
                } else {
                    Circle()
                        .frame(width: 11, height: 11, alignment: .center)
                        .foregroundColor(ipfsState.online ? Color.green : Color.red)
                    Text(ipfsState.online ? "Online" : "Offline")
                        .font(.body)

                    Spacer()

                    Menu {
                        Button {
                            planetStore.isCreatingPlanet = true
                        } label: {
                            Label("Create Planet", systemImage: "plus")
                        }
                        .disabled(planetStore.isCreatingPlanet)

                        Divider()

                        Button {
                            planetStore.isFollowingPlanet = true
                        } label: {
                            Label("Follow Planet", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24, alignment: .center)
                    }
                    .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
                    .frame(width: 24, height: 24, alignment: .center)
                    .menuStyle(BorderlessButtonMenuStyle())
                    .menuIndicator(.hidden)
                }
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !ipfsState.isOperating else { return }
                Task { @MainActor in
                    self.ipfsState.isShowingStatus = true
                }
            }
            .popover(
                isPresented: $ipfsState.isShowingStatus,
                arrowEdge: .top
            ) {
                IPFSStatusView()
                    .environmentObject(ipfsState)
            }
        }
        .sheet(isPresented: $planetStore.isFollowingPlanet) {
            FollowPlanetView()
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
            CreatePlanetView()
        }
        .frame(minWidth: 220, idealWidth: UserDefaults.standard.double(forKey: "sidebarWidth") > 0 ? UserDefaults.standard.double(forKey: "sidebarWidth") : 220) // See https://github.com/Planetable/Planet/issues/393
        .toolbar {
            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .help("Toggle Sidebar")
            }

            if #available(macOS 14.0, *) {
                Spacer()
            }

            Menu {
                Button {
                    PlanetAppDelegate.shared.openTemplateWindow()
                } label: {
                    Text("Template Browser")
                }

                Button {
                    PlanetAppDelegate.shared.openPublishedFoldersDashboardWindow()
                } label: {
                    Text("Published Folders")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .publishMyPlanet)) {
            aNotification in
            if let userObject = aNotification.object, let planet = userObject as? MyPlanetModel {
                Task(priority: .background) {
                    do {
                        try await planet.publish()
                    }
                    catch {
                        debugPrint("Failed to publish: \(planet.name) id=\(planet.id) error=\(error)")
                    }
                }
            }
        }
        .onReceive(timer1m) { _ in
            // Run every 60 seconds (1 minute)
            Task {
                await planetStore.checkPinnable()
            }
        }
        .onReceive(timer3m) { _ in
            // Run every 180 seconds (3 minutes)
            Task {
                await planetStore.pin()
            }
        }
        .onReceive(timer5m) { _ in
            // Run every 300 seconds (5 minutes)
            Task {
                await planetStore.aggregate()
            }
        }
        .onWidthChange { newWidth in
            @AppStorage("sidebarWidth") var sidebarWidth = 220.0
            sidebarWidth = newWidth
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI

struct PlanetSidebarView: View {
    @EnvironmentObject var planetStore: PlanetStore
    @StateObject var ipfs = IPFSState.shared

    @State var isShowingDeleteConfirmation = false
    @State var planetToBeDeleted: MyPlanetModel? = nil

    var body: some View {
        VStack {
            List {
                Section(
                    header: HStack {
                        Text("Smart Feeds")
                        Spacer()
                    }
                ) {
                    NavigationLink(
                        destination: ArticleListView(articles: []),
                        tag: PlanetDetailViewType.today,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .today)
                    }
                    NavigationLink(
                        destination: ArticleListView(articles: []),
                        tag: PlanetDetailViewType.unread,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .unread)
                    }
                    NavigationLink(
                        destination: ArticleListView(articles: []),
                        tag: PlanetDetailViewType.starred,
                        selection: $planetStore.selectedView
                    ) {
                        SmartFeedView(feedType: .starred)
                    }
                }

                Section(
                    header: HStack {
                        Text("My Planets")
                        Spacer()
                    }
                ) {
                    ForEach(planetStore.myPlanets) { planet in
                        NavigationLink(
                            destination: ArticleListView(articles: []).frame(minWidth: 300),
                            tag: PlanetDetailViewType.myPlanet(planet),
                            selection: $planetStore.selectedView
                        ) {
                            VStack {
                                HStack(spacing: 4) {
                                    MyPlanetAvatarView(planet: planet)
                                    Text(planet.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    LoadingIndicatorView()
                                        .opacity(planet.isPublishing ? 1.0 : 0.0)
                                }
                            }
                        }
                            .contextMenu(menuItems: {
                                VStack {
                                    Button {
                                        // PlanetWriterManager.shared.launchWriter(forPlanet: planet)
                                    } label: {
                                        Text("New Article")
                                    }

                                    Button {
                                        Task {
                                            try await planet.publish()
                                        }
                                    } label: {
                                        Text(planet.isPublishing ? "Publishing" : "Publish Planet")
                                    }
                                        .disabled(planet.isPublishing)

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString("planet://\(planet.ipns)", forType: .string)
                                    } label: {
                                        Text("Copy URL")
                                    }

                                    Button {
                                        if let url = planet.browserURL {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } label: {
                                        Text("Open in Public Gateway")
                                    }

                                    Divider()

                                    Button {
                                        isShowingDeleteConfirmation = true
                                        planetToBeDeleted = planet
                                    } label: {
                                        Text("Delete Planet")
                                    }
                                }
                            })
                    }
                }

                Section(
                    header: HStack {
                        Text("Following Planets")
                        Spacer()
                    }
                ) {
                    ForEach(planetStore.followingPlanets) { planet in
                        NavigationLink(
                            destination: ArticleListView(articles: []),
                            tag: PlanetDetailViewType.followingPlanet(planet),
                            selection: $planetStore.selectedView
                        ) {
                            VStack {
                                HStack(spacing: 4) {
                                    FollowingPlanetAvatarView(planet: planet)
                                    Text(planet.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if planet.isUpdating {
                                        LoadingIndicatorView()
                                    }
                                }
                                    .badge(planet.articles.filter { $0.read == nil }.count)
                            }
                        }
                            .contextMenu(menuItems: {
                                VStack {
                                    Button {
                                        Task.init {
                                            try await planet.update()
                                        }
                                    } label: {
                                        Text(planet.isUpdating ? "Updating..." : "Check for update")
                                    }
                                        .disabled(planet.isUpdating)

                                    Button {
                                        planet.articles.forEach { $0.read = Date() }
                                    } label: {
                                        Text("Mark All as Read")
                                    }


                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString("planet://\(planet.link)", forType: .string)
                                    } label: {
                                        Text("Copy URL")
                                    }


                                    Divider()

                                    Button {
                                        planetStore.followingPlanets.removeAll { $0.id == planet.id }
                                        planet.delete()
                                    } label: {
                                        Text("Unfollow")
                                    }
                                }
                            })
                    }
                }
            }
                .listStyle(.sidebar)

            HStack(spacing: 6) {
                Circle()
                    .frame(width: 11, height: 11, alignment: .center)
                    .foregroundColor(ipfs.online ? Color.green : Color.red)
                Text(ipfs.online ? "Online (\(ipfs.peers))" : "Offline")
                    .font(.body)

                Spacer()

                Menu {
                    Button(action: {
                        planetStore.isCreatingPlanet = true
                    }) {
                        Label("Create Planet", systemImage: "plus")
                    }
                        .disabled(planetStore.isCreatingPlanet)

                    Divider()

                    Button(action: {
                        planetStore.isFollowingPlanet = true
                    }) {
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
                .frame(height: 44)
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .background(Color.secondary.opacity(0.05))
        }
            .padding(.bottom, 0)
            .sheet(isPresented: $planetStore.isFollowingPlanet) {
            } content: {
                FollowPlanetView()
            }
            .sheet(isPresented: $planetStore.isCreatingPlanet) {
            } content: {
                CreatePlanetView()
            }
            .confirmationDialog(
                Text("Are you sure you want to delete this planet? This action cannot be undone."),
                isPresented: $isShowingDeleteConfirmation,
                presenting: planetToBeDeleted
            ) { detail in
                Button(role: .destructive) {
                    planetToBeDeleted?.delete()
                } label: {
                    Text("Delete")
                }
            }
    }

    func getArticles() -> [ArticleModel] {
        // TODO
        return []
    }
}

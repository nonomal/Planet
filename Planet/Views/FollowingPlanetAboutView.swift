import SwiftUI

struct FollowingPlanetAboutView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var planetStore: PlanetStore
    @ObservedObject var planet: FollowingPlanetModel
    @State private var isSharing = false
    @State private var planetIPNS = "planet://"

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    FollowingPlanetAvatarView(planet: planet)
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 5)

                HStack {
                    Spacer()
                    Text(planet.name)
                        .font(.title)
                    Spacer()
                }
                Text(planet.about)
                    .font(.body)

                Spacer()

                HStack {
                    Button {
                        isSharing = true
                        planetIPNS = "planet://" + planet.link
                    } label: {
                        Text("Share")
                    }

                    Button {
                        Task.init {
                            try await planet.update()
                            dismiss()
                        }
                    } label: {
                        Text(planet.isUpdating ? "Updating" : "Update")
                    }
                    .disabled(planet.isUpdating)

                    Spacer()

                    Button {
                        planetStore.followingPlanets.removeAll { $0.id == planet.id }
                        planet.delete()
                    } label: {
                        Text("Unfollow")
                    }

                }
            }
            .background(
                SharingServicePicker(isPresented: $isSharing, sharingItems: [planetIPNS])
            )

            VStack {
                HStack {
                    Text(lastUpdatedText())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.cancelAction)
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 320, height: 260, alignment: .center)
    }

    private func lastUpdatedText() -> String {
        "Updated " + planet.lastLocalUpdate.relativeDateDescription()
    }
}

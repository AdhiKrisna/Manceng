import SwiftUI

struct MainView: View {
    @Binding var selectedTab: Tab
    @State private var path = NavigationPath()

    enum Tab: Hashable {
        case home, map, history
    }

    enum Destination: Hashable {
        case camera
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(Tab.home)
                
                MapView()
                    .tabItem {
                        Label("Maps", systemImage: "map.fill")
                    }
                    .tag(Tab.map)
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "fish.fill")
                    }
                    .tag(Tab.history)
            }
            .tint(.NeutralColorPrimaryWhite)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .animation(.none, value: selectedTab)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button(action: {
                        path.append(Destination.camera)
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .frame(width: 56, height: 56)
                            .background(.regularMaterial, in: Circle())
                    }
                    .foregroundStyle(Color.NeutralColorPrimaryWhite)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                    case .camera: CameraView()
                }
            }
        }
    }
}

#Preview {
    MainView(selectedTab: .constant(.home))
}

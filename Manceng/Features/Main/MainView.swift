import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedTab: Tab = .home
    @State private var path = NavigationPath()
    @Environment(\.modelContext) private var modelContext

    enum Tab: Hashable {
        case home, map, history
    }

    enum Destination: Hashable {
        case camera
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selectedTab) {
                HomeView().tag(Tab.home)
                MapView().tag(Tab.map)
                HistoryView().tag(Tab.history)
            }
            .toolbar(.hidden, for: .tabBar)
            .animation(.none, value: selectedTab)
            .safeAreaInset(edge: .bottom) {
                CustomTabBar(selectedTab: $selectedTab) {
                    path.append(Destination.camera)
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .camera:
                    CameraView { savedCatch in
                        modelContext.insert(savedCatch)
                        try? modelContext.save()
                        selectedTab = .home
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}

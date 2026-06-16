import SwiftUI

struct MainView: View {
    @Binding var selectedTab: Tab
    var showWalkthrough: Bool = false
    var onWalkthroughComplete: () -> Void = {}

    @State private var path = NavigationPath()
    @State private var walkthroughStep = 0

    enum Tab: Hashable {
        case home, map, history, camera
    }

    enum Destination: Hashable {
        case camera
    }

    private let walkthroughSteps: [WalkthroughStep] = [
        WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches."),
        WalkthroughStep(text: "See all the locations where you caught your fish."),
        WalkthroughStep(text: "Browse every verified catch you've recorded."),
        WalkthroughStep(text: "Scan your catch to instantly get species, length, and weight.")
    ]

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(Tab.home)

                    MapView()
                        .tabItem { Label("Maps", systemImage: "map.fill") }
                        .tag(Tab.map)

                    HistoryView()
                        .tabItem { Label("History", systemImage: "fish.fill") }
                        .tag(Tab.history)

                    // Tab item tetap muncul di tab bar native,
                    // tapi di-intercept onChange sehingga push navigasi.
                    Color.clear
                        .tabItem { Label("Camera", systemImage: "camera.fill") }
                        .tag(Tab.camera)
                }
                .onChange(of: selectedTab) { old, new in
                    if new == .camera {
                        selectedTab = old
                        path.append(Destination.camera)
                    }
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .camera: CameraView()
                    }
                }
            }

            if showWalkthrough {
                MainWalkthroughView(
                    steps: walkthroughSteps,
                    currentStep: $walkthroughStep,
                    onNext: advanceWalkthrough
                )
            }
        }
        .onAppear {
            if showWalkthrough { syncSelectedTab(walkthroughStep) }
        }
        .onChange(of: walkthroughStep) { _, newValue in
            syncSelectedTab(newValue)
        }
    }

    private func advanceWalkthrough() {
        if walkthroughStep < walkthroughSteps.count - 1 {
            walkthroughStep += 1
        } else {
            selectedTab = .home
            onWalkthroughComplete()
        }
    }

    private func syncSelectedTab(_ step: Int) {
        switch step {
        case 0: selectedTab = .home
        case 1: selectedTab = .map
        case 2: selectedTab = .history
        default: break // camera step: hanya highlight tab, tidak navigasi
        }
    }
}

#Preview {
    MainView(selectedTab: .constant(.home))
}

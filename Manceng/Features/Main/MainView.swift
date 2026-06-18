import SwiftUI
import SwiftData

struct MainView: View {
    @Binding var selectedTab: Tab
    var showWalkthrough: Bool = false
    var onWalkthroughComplete: () -> Void = {}

    @State private var path = NavigationPath()
    @State private var walkthroughStep = 0
    @Environment(\.modelContext) private var modelContext

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

                    // Tab camera sebagai trigger interseptor
                    Color.clear
                        .tabItem { Label("Camera", systemImage: "camera.fill") }
                        .tag(Tab.camera)
                }.tint(Color.white)
                .onChange(of: selectedTab) { old, new in
                    if new == .camera {
                        // Kembalikan seleksi tab ke tab sebelumnya agar posisi tidak stuck di tab kosong
                        selectedTab = old
                        // Push ke CameraView melalui NavigationPath
                        path.append(Destination.camera)
                    }
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .camera:
                        CameraView { catchModel in
                            // 1. Simpan data ke SwiftData
                            modelContext.insert(catchModel)
                            do {
                                try modelContext.save()
                            } catch {
                                print("Failed to save catch: \(error)")
                            }
                            
                            // 2. Set tab kembali ke home setelah selesai memotret/menyimpan
                            selectedTab = .home
                            
                            // 3. KUNCI PERBAIKAN: Pop stack navigasi agar kembali ke MainView asli (bukan tertahan di Camera)
                            if !path.isEmpty {
                                path.removeLast()
                            }
                        }
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
        default: break
        }
    }
}

#Preview {
    MainView(selectedTab: .constant(.home))
}

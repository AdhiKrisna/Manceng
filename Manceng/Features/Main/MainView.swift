import SwiftUI
import UIKit

struct MainView: View {
    @Binding var selectedTab: Tab
    var showWalkthrough: Bool = false
    var onWalkthroughComplete: () -> Void = {}

    @State private var path = NavigationPath()
    @State private var walkthroughStep = 0
    @State private var showCameraSettingsAlert = false
    @State private var isOpeningCamera = false

    enum Tab: Hashable {
        case home, map, history, camera
    }

    enum Destination: Hashable {
        case camera
        case catchDetail(CatchModel)
    }

    private let walkthroughSteps: [WalkthroughStep] = [
        WalkthroughStep(text: "View your 5 latest, heaviest, or longest catches."),
        WalkthroughStep(text: "See all the locations where you caught your fish."),
        WalkthroughStep(text: "Browse every verified catch you've recorded."),
        WalkthroughStep(text: "Scan your catch to instantly get species, length, and weight.")
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                // Main Content
                Group {
                    switch selectedTab {
                    case .home: HomeView()
                    case .map:
                        MapView { catchModel in
                            path.append(Destination.catchDetail(catchModel))
                        }
                    case .history:
                        HistoryView { catchModel in
                            path.append(Destination.catchDetail(catchModel))
                        }
                    case .camera:
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden)
                
                // Custom Tab Bar
                HStack(spacing: 10) {
                    // Left Capsule (Navigation)
                    HStack(spacing: 0) {
                        tabItemButton(
                            title: "Home",
                            icon: "house.fill",
                            tab: .home
                        )
                        tabItemButton(
                            title: "Maps",
                            icon: "map.fill",
                            tab: .map
                        )
                        tabItemButton(
                            title: "History",
                            icon: "fish.fill",
                            tab: .history
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .glassEffect(in: Capsule())
                    // .glassEffect(.regular.interactive(), in: Capsule())
                    .frame(maxWidth: .infinity)

                    // Right Circle (Camera Action)
                    Button {
                        handleCameraTabSelection()
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.neutralColorPrimaryBlack1)
                            .frame(width: 72, height: 72)
                            .glassEffect(in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(GlassPressStyle())
                    .disabled(isOpeningCamera)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Walkthrough
                if showWalkthrough {
                    MainWalkthroughView(
                        steps: walkthroughSteps,
                        currentStep: $walkthroughStep,
                        onNext: advanceWalkthrough
                    )
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .camera:
                    CameraView { _ in
                        selectedTab = .home
                        
                        if !path.isEmpty {
                            path.removeLast()
                        }
                    }
                    .onDisappear {
                        isOpeningCamera = false
                    }
                case .catchDetail(let catchModel):
                    CatchDetailView(catchModel: catchModel)
                }
            }
            .alert("Camera access needed", isPresented: $showCameraSettingsAlert) {
                Button("Settings") {
                    openCameraSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Aktifkan akses Camera di Settings untuk membuka fitur capture.")
            }
        }
        .onAppear {
            if showWalkthrough { syncSelectedTab(walkthroughStep) }
        }
        .onChange(of: walkthroughStep) { _, newValue in
            syncSelectedTab(newValue)
        }
    }
    
    private func tabItemButton(title: String, icon: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.neutralColorPrimaryBlack1).opacity(0.2)
                }
            }
            .foregroundColor(isSelected ? .blue : .neutralColorPrimaryBlack1)
        }
        .buttonStyle(GlassPressStyle())
    }

    private func openCameraSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    private func handleCameraTabSelection() {
        guard !isOpeningCamera else { return }
        let permissionService = CameraPermissionService()

        switch permissionService.currentState() {
        case .authorized:
            isOpeningCamera = true
            path.append(Destination.camera)
        case .notDetermined:
            isOpeningCamera = true
            Task { @MainActor in
                let permissionState = await permissionService.requestAccess()
                if permissionState.canUseCamera {
                    path.append(Destination.camera)
                } else {
                    showCameraSettingsAlert = true
                    isOpeningCamera = false
                }
            }
        case .denied, .restricted:
            showCameraSettingsAlert = true
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

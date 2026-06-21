//
//  HomeView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 15/06/26.
//

import SwiftUI
import SwiftData
import RealityKit
import Combine

struct HomeView: View {
    @Query(sort: \CatchModel.capturedAt, order: .reverse) private var catches: [CatchModel]

    // Sort option menggunakan component SortButton
    @State private var selectedSort: SortOption = .latest

    // Model 3D ikan untuk state kosong (drag saja, tanpa gyro).
    @StateObject private var model3DMotion = Model3DMotionManager()
    @State private var interaction = FishInteractionState()

    // Navigasi ke halaman detail.
    @State private var showDetail = false
    @State private var detailCatch: CatchModel?

    // Ikan yang sedang fokus di carousel (penentu nilai ruler/berat/judul sticky).
    @State private var currentCatchID: UUID?

    /// Ikan yang ditampilkan, diurutkan sesuai filter, maksimal 5.
    private var displayedCatches: [CatchModel] {
        let sorted: [CatchModel]
        switch selectedSort {
        case .latest: sorted = catches.sorted { $0.capturedAt > $1.capturedAt }
        case .weight: sorted = catches.sorted { $0.weight > $1.weight }
        case .length: sorted = catches.sorted { $0.length > $1.length }
        }
        return Array(sorted.prefix(5))
    }

    // Latest → ruler + berat; Length → ruler saja; Weight → berat saja.
    private var showRuler: Bool { selectedSort != .weight }
    private var showWeight: Bool { selectedSort != .length }

    var body: some View {
        ZStack {
            Color.brandColorPrimaryYellow
                .ignoresSafeArea()

            if catches.isEmpty {
                emptyState
            } else {
                filledPager
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            if let c = detailCatch {
                CatchDetailView(catchModel: c)
            } else {
                CatchDetailView()
            }
        }
    }

    // MARK: - State terisi: hanya ikan yang bisa di-slide; objek lain sticky

    /// Ikan yang sedang fokus (untuk nilai ruler/berat/judul yang sticky).
    private var currentCatch: CatchModel? {
        if let id = currentCatchID {
            return displayedCatches.first { $0.id == id } ?? displayedCatches.first
        }
        return displayedCatches.first
    }

    private var filledPager: some View {
        ZStack {
            // Lapisan ikan — SATU-SATUNYA yang bisa di-slide.
            fishCarousel

            // Penggaris kiri — sticky (nilai ikut ikan yang sedang fokus).
            // Karena ada di kiri, preview ikan berikutnya tampak di sisi kanan.
            if showRuler, let c = currentCatch {
                HStack {
                    RulerView(maxCm: max(1, Int(c.length.rounded())))
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Badge berat kanan — sticky. Preview ikan berikutnya tampak di kiri.
            if showWeight, let c = currentCatch {
                HStack {
                    Spacer()
                    WeightView(weight: c.weight)
                }
                .allowsHitTesting(false)
            }

            // Judul nama ikan — sticky di atas.
            VStack {
                Text(currentCatch?.species ?? "")
                    .font(.title1Bold)
                    .foregroundColor(.neutralColorPrimaryBlack1)
                    .padding(.top, 8)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            SortButton(selectedSort: $selectedSort)
                .padding(.trailing, 20)
                .padding(.top, 8)
        }
        .onAppear {
            if currentCatchID == nil { currentCatchID = displayedCatches.first?.id }
        }
        .onChange(of: selectedSort) { _, _ in
            currentCatchID = displayedCatches.first?.id
        }
    }

    private var fishCarousel: some View {
        GeometryReader { geo in
            fishScrollView(geo: geo)
        }
    }
    
    @ViewBuilder
    private func fishScrollView(geo: GeometryProxy) -> some View {
        ZStack {
            let currentFishPeek = calculateCurrentFishPeek(screenWidth: geo.size.width)
            let itemWidth = geo.size.width - currentFishPeek * 2
            let transitionOpacity = getScrollTransitionOpacity(for: selectedSort)
            let transitionScale = getScrollTransitionScale(for: selectedSort)
            let transitionYOffset = getScrollTransitionYOffset(for: selectedSort)
            
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if selectedSort != .latest {
                        Color.clear.frame(width: currentFishPeek)
                    }
                    
                    ForEach(displayedCatches) { c in
                        let lengthCm = max(1, Int(c.length.rounded()))
                        let rulerLengthCm = min(lengthCm, 60)
                        let fishHeight = CGFloat(rulerLengthCm) * 8
                        let isActive = currentCatchID == c.id
                        
                        VStack(spacing: 0) {
                            Image(uiImage: c.image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: fishHeight)
                                .shadow(color: isActive ? .black.opacity(0.35) : .clear, radius: isActive ? 18 : 0, x: 0, y: isActive ? 30 : 0)
                                .overlay(alignment: .bottom) {
                                    if isActive {
                                        Ellipse()
                                            .fill(.black.opacity(0.22))
                                            .blur(radius: 16)
                                            .frame(width: 120, height: 25)
                                            .offset(y: 52)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    detailCatch = c
                                    showDetail = true
                                }
                        }
                        .frame(width: itemWidth, height: geo.size.height)
                        .scrollTransition { content, phase in
                            content.opacity(phase.isIdentity ? 1 : transitionOpacity)
                                .scaleEffect(phase.isIdentity ? 1 : transitionScale)
                                .offset(y: phase.isIdentity ? 0 : transitionYOffset)
                        }
                    }
                    
                    if selectedSort != .latest {
                        Color.clear.frame(width: currentFishPeek)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, currentFishPeek, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentCatchID)
            .scrollIndicators(.hidden)
            .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentCatchID)
        }
    }
    
    private func calculateCurrentFishPeek(screenWidth: CGFloat) -> CGFloat {
        switch selectedSort {
        case .latest:
            return 0
        case .length, .weight:
            return screenWidth * 0.25
        }
    }
    
    private func getScrollTransitionOpacity(for sort: SortOption) -> Double {
        switch sort {
        case .latest: return 1
        case .weight: return 0.4
        case .length: return 0.5
        }
    }
    
    private func getScrollTransitionScale(for sort: SortOption) -> Double {
        switch sort {
        case .latest: return 1
        case .weight: return 0.82
        case .length: return 0.85
        }
    }
    
    private func getScrollTransitionYOffset(for sort: SortOption) -> CGFloat {
        switch sort {
        case .latest: return 0
        case .weight: return 0
        case .length: return 10
        }
    }

    // MARK: - State kosong: model 3D ikan interaktif & dapat ditekan

    private var emptyState: some View {
        VStack(spacing: 24) {
            // Hanya dirender saat halaman detail TIDAK aktif: dua RealityView
            // yang hidup bersamaan saling bentrok (salah satunya jadi kosong).
            Group {
                if showDetail {
                    Color.clear
                } else {
                    FishModelView(
                        motion: model3DMotion,
                        interaction: interaction,
                        onSingleTap: {
                            detailCatch = nil
                            showDetail = true
                        },
                        extraYawDegrees: 90,
                        fillSize: 0.45,
                        allowZoom: false
                    )
                }
            }
            .frame(height: 320)

            VStack(spacing: 8) {
                Text("No catches recorded yet!")
                    .font(.title1Semibold)
                    .foregroundColor(.neutralColorPrimaryBlack1)

                Text("Tap camera button below to get started!")
                    .font(.caption1Bold)
                    .foregroundColor(.neutralColorPrimaryBlack1.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
    }
}

#Preview {
    HomeView()
}

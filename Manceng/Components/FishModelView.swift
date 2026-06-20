//
//  FishModelView.swift
//  Manceng
//
//  Menampilkan model 3D ikan (tenggiri.usdc dari Assets.xcassets) memakai
//  RealityView, dengan kombinasi tiga input rotasi/skala:
//    1. Gyro (MotionManager)  -> rotasi dasar mengikuti kemiringan device
//    2. DragGesture           -> offset rotasi manual (sumbu Y & X)
//    3. MagnifyGesture        -> zoom in/out (pinch)
//
//  Anti-lag: orientasi entity di-update langsung di render loop RealityKit
//  (subscription ke SceneEvents.Update), BUKAN lewat closure `update:` milik
//  RealityView. Dengan begitu tidak ada re-render SwiftUI per frame.
//
//  Loader & lighting bersama ada di Model3DSupport.swift.
//

import RealityKit
import SwiftUI

// MARK: - State interaksi

/// State gesture yang dibaca langsung oleh render loop RealityKit tiap frame.
/// Sengaja berupa class biasa (bukan @State value / @Published) supaya
/// perubahan per-frame TIDAK memicu re-render SwiftUI — ini kunci anti-lag.
/// Dipakai juga oleh halaman Timbangan (ScaleModelView).
final class FishInteractionState {
    /// Rotasi sumbu Y (kiri/kanan) hasil drag yang sudah "dilepas" (akumulasi).
    var committedYaw: Float = 0
    /// Rotasi sumbu Y selama jari masih menempel.
    var activeYaw: Float = 0
    /// Rotasi sumbu X (atas/bawah) hasil drag yang sudah dilepas (akumulasi).
    var committedPitch: Float = 0
    /// Rotasi sumbu X selama jari masih menempel.
    var activePitch: Float = 0
    /// Skala zoom hasil pinch yang sudah dilepas.
    var committedZoom: Float = 1
    /// Skala zoom selama pinch berlangsung.
    var activeZoom: Float = 1
    /// Token subscription render loop (harus disimpan agar tetap hidup).
    var updateSubscription: EventSubscription?

    /// Saat true, render loop menganimasikan nilai-nilai di atas kembali ke
    /// pose awal secara bertahap (bukan langsung lompat).
    var isResetting = false

    /// Minta reset ke posisi awal. Animasinya dikerjakan render loop
    /// mulai dari pose terakhir, jadi transisinya halus.
    func reset() {
        // Pindahkan sisa drag yang masih aktif ke nilai akumulasi dulu,
        // supaya animasi benar-benar berangkat dari pose yang terlihat.
        committedYaw += activeYaw
        committedPitch += activePitch
        committedZoom *= activeZoom
        activeYaw = 0
        activePitch = 0
        activeZoom = 1

        // Wrap yaw ke rentang (-180°...180°]: kalau user sudah memutar
        // beberapa putaran penuh, animasi pulang cukup lewat jalur
        // TERPENDEK — tidak ikut "membongkar" semua putarannya.
        committedYaw = atan2(sin(committedYaw), cos(committedYaw))

        isResetting = true
    }

    /// Satu langkah animasi reset, dipanggil render loop tiap frame.
    /// Decay 0.95/frame ≈ animasi ~1 detik @60fps — pelan & smooth.
    func stepResetAnimationIfNeeded() {
        guard isResetting else { return }
        committedYaw *= 0.95
        committedPitch *= 0.95
        committedZoom += (1 - committedZoom) * 0.05
        if abs(committedYaw) < 0.003,
           abs(committedPitch) < 0.003,
           abs(committedZoom - 1) < 0.003 {
            committedYaw = 0
            committedPitch = 0
            committedZoom = 1
            isResetting = false
        }
    }
}

// MARK: - View

struct FishModelView: View {

    /// Sumber data gyro (dimiliki oleh parent agar lifecycle-nya jelas).
    let motion: Model3DMotionManager

    /// State interaksi bersama antara gesture SwiftUI dan render loop RealityKit.
    /// Dimiliki parent supaya tombol reset di luar view ini bisa mengaksesnya.
    let interaction: FishInteractionState

    /// Aksi opsional saat model di-tap sekali (mis. buka halaman detail ikan).
    /// Double-tap tetap untuk reset; single-tap dikenali setelah jeda singkat.
    var onSingleTap: (() -> Void)? = nil

    /// Rotasi tambahan pada sumbu Y (derajat) di atas orientasi dasar otomatis.
    var extraYawDegrees: Float = 0

    /// Target normalisasi: dimensi terbesar model jadi sebesar ini (meter dunia).
    /// Makin besar = ikan tampil lebih besar.
    var fillSize: Float = 0.28

    /// Izinkan pinch zoom. Bila false, ukuran terkunci (tidak bisa zoom in/out).
    var allowZoom: Bool = true

    /// Seberapa besar pengaruh gyro terhadap rotasi model. Sengaja rendah
    /// supaya ikan hanya "menengok" halus mengikuti device, tidak heboh.
    private let gyroInfluence: Float = 0.5
    /// Konversi piksel drag -> radian.
    private let dragSensitivity: Float = 0.012

    var body: some View {
        RealityView { content in
            // --- Kamera virtual (non-AR) supaya jalan juga di simulator ---
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 0.55] // 55 cm di depan objek
            content.add(camera)

            // --- Lampu studio dari depan + IBL glossy (helper bersama) ---
            SceneLighting.makeStudioLights().forEach { content.add($0) }

            // --- Muat model ikan secara async ---
            let fish = await ModelAssetLoader.load(named: "tenggiri")
                ?? ModelAssetLoader.placeholderBox()

            // --- Orientasi dasar: ikan harus tampil MENYAMPING ---
            // Deteksi otomatis dari bounding box: sumbu terpanjang model
            // (= panjang badan ikan) diputar agar sejajar sumbu X (horizontal
            // di layar), lalu pastikan profil LEBAR badan yang menghadap kamera
            // (bukan sisi tipisnya). Pose inilah yang jadi "posisi semula"
            // saat tombol reset ditekan.
            let rawExtents = fish.visualBounds(relativeTo: nil).extents
            var baseOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            if rawExtents.y >= rawExtents.x && rawExtents.y >= rawExtents.z {
                // Badan memanjang di sumbu Y (ikan "berdiri") -> rebahkan ke sumbu X.
                baseOrientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
            } else if rawExtents.z >= rawExtents.x && rawExtents.z >= rawExtents.y {
                // Badan memanjang di sumbu Z (menghadap kamera) -> putar ke samping.
                baseOrientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            }
            fish.orientation = baseOrientation

            // Setelah direbahkan, kalau ketebalan ke arah kamera (Z) masih lebih
            // besar dari tinggi badan (Y), berarti yang menghadap kamera sisi
            // tipisnya -> gulingkan 90° pada sumbu X agar profil lebar terlihat.
            let lyingExtents = fish.visualBounds(relativeTo: nil).extents
            if lyingExtents.z > lyingExtents.y {
                fish.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * baseOrientation
            }

            // Rotasi tambahan pada sumbu Y (mis. 90°) di atas orientasi dasar.
            if extraYawDegrees != 0 {
                let yawRad = extraYawDegrees * .pi / 180
                fish.orientation = simd_quatf(angle: yawRad, axis: [0, 1, 0]) * fish.orientation
            }

            // Normalisasi ukuran: skala model agar dimensi terbesarnya = fillSize
            // di dunia virtual, lalu geser supaya pusat bounding box ada di origin.
            // (Bounds dihitung ulang SETELAH orientasi dasar diterapkan.)
            let bounds = fish.visualBounds(relativeTo: nil)
            let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let normalizeScale = maxExtent > 0 ? fillSize / maxExtent : 1
            fish.scale = SIMD3(repeating: normalizeScale)
            fish.position = -bounds.center * normalizeScale

            // Pertajam kilap material agar refleksi IBL terlihat glossy.
            Self.applyGloss(to: fish)

            // Container terpisah: rotasi & zoom diterapkan ke container,
            // sehingga tidak menimpa skala normalisasi milik si ikan.
            let container = Entity()
            container.addChild(fish)
            content.add(container)

            // --- Image-Based Lighting "studio" untuk efek glossy ---
            if let iblEntity = await SceneLighting.makeImageBasedLight() {
                content.add(iblEntity)
                SceneLighting.attachReceiver(to: container, lightEntity: iblEntity)
            }

            // --- Update per-frame di render loop RealityKit (anti-lag) ---
            // Closure ini dipanggil RealityKit setiap frame; membaca gyro +
            // gesture langsung tanpa melewati siklus render SwiftUI.
            let state = interaction
            let motion = motion
            let influence = gyroInfluence
            state.updateSubscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                // Animasi reset (kalau sedang berjalan) — smooth, dari pose terakhir.
                state.stepResetAnimationIfNeeded()

                // Kontribusi gyro dibatasi dengan SOFT-limit (tanh): makin dekat
                // batas makin pelan, tapi tidak pernah "mentok" mendadak seperti
                // hard clamp. Envelope sengaja kecil (~20° yaw, ~14° pitch) agar
                // ikan tidak terlalu bergerak saat device dimiringkan.
                let yawLimit: Float = 0.35
                let pitchLimit: Float = 0.25
                let gyroYaw = yawLimit * tanh(Float(motion.roll) * influence / yawLimit)
                let gyroPitch = pitchLimit * tanh(Float(motion.pitch) * influence / pitchLimit)

                // Gabungan rotasi: gyro sebagai base, drag sebagai offset tambahan.
                let yaw = state.committedYaw + state.activeYaw + gyroYaw
                // Pitch dari drag dibatasi ±70° agar ikan tidak terbalik.
                let dragPitch = min(max(state.committedPitch + state.activePitch, -1.2), 1.2)
                let pitch = dragPitch + gyroPitch

                // Pitch (sumbu X) duluan agar terasa seperti "mendongak",
                // lalu yaw (sumbu Y) untuk memutar ikan ke kiri/kanan.
                container.orientation =
                    simd_quatf(angle: pitch, axis: [1, 0, 0]) *
                    simd_quatf(angle: yaw, axis: [0, 1, 0])

                // Zoom dari pinch, dibatasi agar tidak terlalu kecil/besar.
                let zoom = min(max(state.committedZoom * state.activeZoom, 0.5), 2.5)
                container.scale = SIMD3(repeating: zoom)
            }
        }
        // --- Drag: horizontal memutar sumbu Y, vertikal memutar sumbu X ---
        // Gesture hanya menulis ke FishInteractionState (class), tidak menyentuh
        // @State value, jadi tidak ada re-render SwiftUI selama drag.
        .gesture(
            DragGesture()
                .onChanged { value in
                    interaction.isResetting = false // drag membatalkan animasi reset
                    interaction.activeYaw = Float(value.translation.width) * dragSensitivity
                    // Drag ke bawah = ikan "mendongak" (rotasi sumbu X positif).
                    interaction.activePitch = Float(value.translation.height) * dragSensitivity
                }
                .onEnded { value in
                    interaction.committedYaw += Float(value.translation.width) * dragSensitivity
                    interaction.activeYaw = 0
                    // Akumulasi pitch ikut di-clamp ±70° agar tidak terbalik permanen.
                    interaction.committedPitch = min(max(
                        interaction.committedPitch + Float(value.translation.height) * dragSensitivity,
                        -1.2), 1.2)
                    interaction.activePitch = 0
                }
        )
        // --- Pinch: zoom in/out (di-skip bila allowZoom == false) ---
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    guard allowZoom else { return }
                    interaction.isResetting = false // pinch membatalkan animasi reset
                    interaction.activeZoom = Float(value.magnification)
                }
                .onEnded { value in
                    guard allowZoom else { return }
                    interaction.committedZoom = min(
                        max(interaction.committedZoom * Float(value.magnification), 0.5), 2.5
                    )
                    interaction.activeZoom = 1
                }
        )
        // --- Double-tap: reset rotasi/zoom & kalibrasi ulang titik nol gyro ---
        .onTapGesture(count: 2) {
            interaction.reset()
            motion.recalibrate()
        }
        // --- Single-tap: aksi opsional (mis. buka halaman detail ikan) ---
        .onTapGesture(count: 1) {
            onSingleTap?()
        }
    }

    // MARK: - Glossy material

    /// Telusuri hierarki entity dan pertajam parameter PBR-nya:
    /// roughness rendah + clearcoat = highlight tajam seperti permukaan basah.
    private static func applyGloss(to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                pbr.roughness = .init(floatLiteral: 0.15)          // makin kecil = makin kilap
                pbr.metallic = .init(floatLiteral: 0.25)           // sedikit metalik utk refleksi
                pbr.clearcoat = .init(floatLiteral: 1.0)           // lapisan "pernis" di atas
                pbr.clearcoatRoughness = .init(floatLiteral: 0.05) // pernis yang sangat halus
                return pbr
            }
            entity.components.set(model)
        }
        entity.children.forEach { applyGloss(to: $0) }
    }
}

#Preview {
    FishModelView(motion: Model3DMotionManager(), interaction: FishInteractionState())
}

//
//  ScaleModelView.swift
//  Manceng
//
//  Menampilkan model 3D timbangan (timbangan.usdc dari Assets.xcassets).
//
//  Pemisahan rotasi — ini inti halaman ini:
//    * ROOT/container  : menerima gyro + drag + pinch (seluruh timbangan
//                        berputar spasial, sama seperti halaman ikan).
//    * PanahTimbangan  : child di dalam hierarki, otomatis IKUT rotasi
//                        root; di atasnya ditambahkan ROTASI LOKAL pada
//                        sumbu dial. Jadi:
//                        total = rotasi parent (gyro/drag) ∘ rotasi lokal jarum.
//
//  Jarum berputar TERUS-MENERUS sendiri dengan kecepatan konstan
//  (tidak digerakkan slider/berat). Sudutnya diakumulasi tiap frame
//  memakai deltaTime dari render loop.
//

import RealityKit
import SwiftUI

// MARK: - State jarum

/// State jarum timbangan yang dibaca render loop tiap frame.
/// Class biasa (bukan @Published) — alasan anti-lag yang sama dengan
/// FishInteractionState.
final class ScaleNeedleState {
    /// Sudut jarum saat ini (radian), terus bertambah tiap frame.
    var currentAngle: Float = 0
}

// MARK: - View

struct ScaleModelView: View {

    /// Sumber data gyro — reuse Model3DMotionManager yang sama dengan halaman ikan.
    let motion: Model3DMotionManager

    /// State gesture (drag/pinch/reset) — reuse FishInteractionState.
    let interaction: FishInteractionState

    /// State sudut jarum, hidup selama view ini ada.
    @State private var needleState = ScaleNeedleState()

    /// Seberapa besar pengaruh gyro terhadap rotasi model.
    private let gyroInfluence: Float = 1.4
    /// Konversi piksel drag -> radian.
    private let dragSensitivity: Float = 0.012

    /// Kecepatan putar jarum (radian per detik). Negatif = searah jarum jam.
    /// ~1.2 rad/s ≈ satu putaran penuh tiap ~5 detik. Sesuaikan sesuai selera;
    /// positifkan nilainya kalau arah putarnya terbalik.
    private let needleSpeed: Float = -1.2

    var body: some View {
        RealityView { content in
            // --- Kamera virtual (non-AR) supaya jalan juga di simulator ---
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 0.55] // 55 cm di depan objek
            content.add(camera)

            // --- Lampu studio dari depan + IBL glossy (helper bersama).
            //     Material PBR dari Blender (base color/roughness/metallic)
            //     dibiarkan apa adanya; IBL-lah yang memunculkan kilapnya. ---
            SceneLighting.makeStudioLights().forEach { content.add($0) }

            // --- Muat model timbangan secara async ---
            let scaleModel = await ModelAssetLoader.load(named: "timbangan")
                ?? ModelAssetLoader.placeholderBox()

            // Normalisasi ukuran: dimensi terbesar ~30 cm, pusat di origin.
            let bounds = scaleModel.visualBounds(relativeTo: nil)
            let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let normalizeScale = maxExtent > 0 ? 0.30 / maxExtent : 1
            scaleModel.scale = SIMD3(repeating: normalizeScale)
            scaleModel.position = -bounds.center * normalizeScale

            // --- Cari jarum penunjuk di dalam hierarki model ---
            // PanahTimbangan tetap menjadi child (ikut rotasi root), tapi
            // kita pegang referensinya untuk rotasi lokal berdasarkan berat.
            let needle = scaleModel.findEntity(named: "PanahTimbangan")
            if needle == nil {
                print("ScaleModelView: entity 'PanahTimbangan' tidak ditemukan — jarum tidak akan bergerak")
            }
            // Orientasi bawaan jarum dari file USDC: rotasi berat diterapkan
            // DI ATAS orientasi ini, bukan menggantikannya.
            let needleBaseOrientation = needle?.transform.rotation ?? simd_quatf(angle: 0, axis: [0, 0, 1])

            // Container: semua rotasi gyro/drag/zoom diterapkan ke sini
            // (= ROOT seluruh timbangan), TIDAK pernah ke jarum langsung.
            let container = Entity()
            container.addChild(scaleModel)
            content.add(container)

            // --- IBL untuk efek glossy material PBR ---
            if let iblEntity = await SceneLighting.makeImageBasedLight() {
                content.add(iblEntity)
                SceneLighting.attachReceiver(to: container, lightEntity: iblEntity)
            }

            // --- Update per-frame di render loop RealityKit (anti-lag) ---
            let state = interaction
            let needleSt = needleState
            let motion = motion
            let influence = gyroInfluence
            let speed = needleSpeed
            state.updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                // Animasi reset gesture (kalau sedang berjalan).
                state.stepResetAnimationIfNeeded()

                // == ROTASI ROOT: gyro (soft-limit tanh) + drag, sama seperti ikan ==
                let gyroYaw = 1.0 * tanh(Float(motion.roll) * influence / 1.0)
                let gyroPitch = 0.8 * tanh(Float(motion.pitch) * influence / 0.8)

                let yaw = state.committedYaw + state.activeYaw + gyroYaw
                let dragPitch = min(max(state.committedPitch + state.activePitch, -1.2), 1.2)
                let pitch = dragPitch + gyroPitch

                container.orientation =
                    simd_quatf(angle: pitch, axis: [1, 0, 0]) *
                    simd_quatf(angle: yaw, axis: [0, 1, 0])

                let zoom = min(max(state.committedZoom * state.activeZoom, 0.5), 2.5)
                container.scale = SIMD3(repeating: zoom)

                // == ROTASI LOKAL JARUM: berputar terus dengan kecepatan konstan ==
                // Karena jarum adalah child dari model (yang child dari
                // container), ia otomatis ikut rotasi gyro/drag di atas;
                // di sini hanya transform LOKAL-nya yang diputar. deltaTime
                // membuat kecepatannya stabil tak peduli frame rate.
                if let needle {
                    needleSt.currentAngle += speed * Float(event.deltaTime)
                    needle.transform.rotation = needleBaseOrientation *
                        simd_quatf(angle: needleSt.currentAngle, axis: [0, 0, 1])
                }
            }
        }
        // --- Drag: horizontal memutar sumbu Y, vertikal memutar sumbu X ---
        .gesture(
            DragGesture()
                .onChanged { value in
                    interaction.isResetting = false // drag membatalkan animasi reset
                    interaction.activeYaw = Float(value.translation.width) * dragSensitivity
                    interaction.activePitch = Float(value.translation.height) * dragSensitivity
                }
                .onEnded { value in
                    interaction.committedYaw += Float(value.translation.width) * dragSensitivity
                    interaction.activeYaw = 0
                    interaction.committedPitch = min(max(
                        interaction.committedPitch + Float(value.translation.height) * dragSensitivity,
                        -1.2), 1.2)
                    interaction.activePitch = 0
                }
        )
        // --- Pinch: zoom in/out ---
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    interaction.isResetting = false
                    interaction.activeZoom = Float(value.magnification)
                }
                .onEnded { value in
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
    }
}

#Preview {
    ScaleModelView(
        motion: Model3DMotionManager(),
        interaction: FishInteractionState()
    )
}

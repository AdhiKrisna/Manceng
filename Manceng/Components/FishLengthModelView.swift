//
//  FishLengthModelView.swift
//  Manceng
//
//  Menampilkan model 3D pengukuran panjang (penggaris.usdc): model ikan +
//  penggaris dengan angka skala 0–10 (entity "_0" … "_10").
//
//  Animasi: angka 1→10 di-ZOOM berurutan & berkala (highlight berjalan),
//  seperti sorotan yang bergerak melewati tiap angka. Tidak ada marker merah
//  dan tidak ada overlay angka yang berganti.
//
//  ORIENTASI DETERMINISTIK (tahan rotasi konversi Blender):
//    Dihitung dari posisi entity asli, BUKAN menebak sudut.
//      rulerDir = arah 0 → maksimum (label "_0" → "_10")  → X layar (mendatar)
//      forward  = arah penggaris → ikan (= NORMAL bidang ikan & angka)
//                 → Z (menghadap KAMERA) — ini yang memperbaiki ikan yang
//                 sebelumnya "tertidur" menghadap ke atas.
//      up       = forward × rulerDir → Y layar.
//    Pemusatan & normalisasi dihitung SETELAH orientasi (benar-benar tengah).
//

import RealityKit
import SwiftUI

// MARK: - State animasi zoom angka

/// Menyimpan entity angka + skala aslinya untuk animasi zoom berjalan.
/// Class biasa → tidak memicu re-render SwiftUI.
final class NumberZoomState {
    var phase: Double = 0
    /// (entity angka, skala asli, nilai angka).
    var numbers: [(entity: Entity, baseScale: SIMD3<Float>, value: Double)] = []
}

// MARK: - View

struct FishLengthModelView: View {

    let motion: Model3DMotionManager
    let interaction: FishInteractionState

    var debugDumpHierarchy: Bool = false

    @State private var zoomState = NumberZoomState()

    private let gyroInfluence: Float = 0.5
    private let dragSensitivity: Float = 0.012

    // MARK: - Konstanta (MUDAH DISESUAIKAN)

    /// Ukuran normalisasi (dimensi terbesar → sebesar ini di dunia).
    private let normalizeSize: Float = 0.30

    /// 0 di kiri (true) atau kanan (false).
    private let zeroOnLeft: Bool = true

    /// Angka pertama & terakhir yang dianimasikan (entity "_0" … "_10").
    private let firstNumber = 0
    private let lastNumber = 10
    /// Seberapa besar angka membesar saat tersorot (1.6 → sampai 2.6×).
    private let zoomAmount: Double = 1.6
    /// Lebar sorotan (berapa angka di sekitar yang ikut membesar).
    private let zoomWidth: Double = 1.2
    /// Kecepatan sorotan berjalan (radian/detik fase). 0.5 → 1 siklus ~12 dtk
    /// (lebih lambat).
    private let zoomSpeed: Double = 0.5

    var body: some View {
        RealityView { content in
            // --- Kamera & lampu ---
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 0.6]
            content.add(camera)
            SceneLighting.makeStudioLights().forEach { content.add($0) }

            // --- Muat model ---
            let model = await ModelAssetLoader.load(named: "penggaris")
                ?? ModelAssetLoader.placeholderBox()
            if debugDumpHierarchy { Self.dumpHierarchy(model, depth: 0) }

            let root = model.findEntity(named: "root") ?? model

            // --- Titik acuan (koordinat LOKAL root) ---
            var p0 = (model.findEntity(named: "_0") ?? model.findEntity(named: "Text_001"))?
                .position(relativeTo: root) ?? SIMD3<Float>(0, 0, 9.99)
            var pMax = (model.findEntity(named: "_10") ?? model.findEntity(named: "Text_002"))?
                .position(relativeTo: root) ?? SIMD3<Float>(0, 0, -11.66)
            if !zeroOnLeft { swap(&p0, &pMax) }

            let fishCenter = model.findEntity(named: "Ikan")?.position(relativeTo: root)
                ?? SIMD3<Float>(0, 5, 0)

            // --- Basis arah (frame root) ---
            let mid = (p0 + pMax) * 0.5
            let rulerDir = simd_normalize(pMax - p0)
            var toFish = fishCenter - mid
            toFish -= simd_dot(toFish, rulerDir) * rulerDir
            let perpLen = simd_length(toFish)
            // forward = arah ke ikan = NORMAL bidang ikan/angka → menghadap kamera.
            let forward = perpLen > 1e-4 ? simd_normalize(toFish) : Self.anyPerp(rulerDir)
            let up = simd_normalize(simd_cross(forward, rulerDir))

            // R memetakan rulerDir→X, up→Y, forward→Z (Z = menghadap kamera).
            let basis = simd_float3x3(columns: (rulerDir, up, forward))
            root.orientation = Self.quat(from: basis.transpose)

            // --- Normalisasi & pemusatan SETELAH orientasi ---
            let bounds = model.visualBounds(relativeTo: nil)
            let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let normScale = maxExtent > 0 ? normalizeSize / maxExtent : 1
            model.scale = SIMD3(repeating: normScale)
            model.position = -bounds.center * normScale

            // --- Kumpulkan entity angka untuk animasi zoom ---
            var nums: [(entity: Entity, baseScale: SIMD3<Float>, value: Double)] = []
            for i in firstNumber...lastNumber {
                if let e = model.findEntity(named: "_\(i)") {
                    nums.append((e, e.scale, Double(i)))
                }
            }
            zoomState.numbers = nums

            // --- container menerima rotasi gyro/drag ---
            let container = Entity()
            container.addChild(model)
            content.add(container)

            // --- IBL glossy ---
            if let iblEntity = await SceneLighting.makeImageBasedLight() {
                content.add(iblEntity)
                SceneLighting.attachReceiver(to: model, lightEntity: iblEntity)
            }

            // --- Update per-frame: rotasi gyro/drag + zoom angka berjalan ---
            let state = interaction
            let motion = motion
            let influence = gyroInfluence
            let zoom = zoomState
            let zSpeed = zoomSpeed, zAmt = zoomAmount, zWidth = zoomWidth
            let first = Double(firstNumber), last = Double(lastNumber)
            state.updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                state.stepResetAnimationIfNeeded()

                // Rotasi container (gyro + drag), sama seperti timbangan.
                // Envelope kecil (~20° yaw, ~14° pitch) supaya gerak halus & terbatas.
                let yawLimit: Float = 0.35
                let pitchLimit: Float = 0.25
                let gyroYaw = yawLimit * tanh(Float(motion.roll) * influence / yawLimit)
                let gyroPitch = pitchLimit * tanh(Float(motion.pitch) * influence / pitchLimit)
                let yaw = state.committedYaw + state.activeYaw + gyroYaw
                let dragPitch = min(max(state.committedPitch + state.activePitch, -1.2), 1.2)
                let pitch = dragPitch + gyroPitch
                container.orientation =
                    simd_quatf(angle: pitch, axis: [1, 0, 0]) *
                    simd_quatf(angle: yaw, axis: [0, 1, 0])
                let zoomScale = min(max(state.committedZoom * state.activeZoom, 0.5), 2.5)
                container.scale = SIMD3(repeating: zoomScale)

                // Sorotan berjalan 1→10→1 (ping-pong), tiap angka di-zoom saat dilewati.
                zoom.phase += event.deltaTime * zSpeed
                let active = first + (last - first) * (0.5 - 0.5 * cos(zoom.phase))
                for item in zoom.numbers {
                    let dist = abs(item.value - active)
                    let f = 1.0 + zAmt * max(0, 1 - dist / zWidth)
                    item.entity.scale = item.baseScale * Float(f)
                }
            }
        }
        // --- Drag, pinch, double-tap (sama seperti timbangan) ---
        .gesture(
            DragGesture()
                .onChanged { value in
                    interaction.isResetting = false
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
        .onTapGesture(count: 2) {
            interaction.reset()
            motion.recalibrate()
        }
    }

    // MARK: - Helper matematika

    private static func quat(from m3: simd_float3x3) -> simd_quatf {
        var m = matrix_identity_float4x4
        m.columns.0 = SIMD4<Float>(m3.columns.0, 0)
        m.columns.1 = SIMD4<Float>(m3.columns.1, 0)
        m.columns.2 = SIMD4<Float>(m3.columns.2, 0)
        return Transform(matrix: m).rotation
    }

    private static func anyPerp(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let ref: SIMD3<Float> = abs(v.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
        return simd_normalize(simd_cross(v, ref))
    }

    // MARK: - Debug

    private static func dumpHierarchy(_ entity: Entity, depth: Int) {
        let pad = String(repeating: "  ", count: depth)
        let name = entity.name.isEmpty ? "(unnamed)" : entity.name
        let p = entity.position(relativeTo: nil)
        print("\(pad)\(name) pos=(\(p.x), \(p.y), \(p.z))")
        for child in entity.children { dumpHierarchy(child, depth: depth + 1) }
    }
}

#Preview {
    FishLengthModelView(
        motion: Model3DMotionManager(),
        interaction: FishInteractionState()
    )
}

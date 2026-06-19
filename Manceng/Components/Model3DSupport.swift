//
//  Model3DSupport.swift
//  TesIkan
//
//  Helper bersama untuk semua halaman 3D (ikan, timbangan, dst.):
//    - ModelAssetLoader : memuat entity .usdc/.usdz dari Assets.xcassets
//    - SceneLighting    : kamera tidak termasuk; lampu studio + IBL glossy
//

import RealityKit
import SwiftUI

// MARK: - Loader

/// Memuat entity model 3D dari bundle. Karena file .usdc disimpan di dalam
/// Assets.xcassets sebagai *dataset*, file tidak bisa diakses langsung lewat
/// Entity(named:). Strateginya:
///   1. Coba Entity(named:) — untuk file yang ditaruh di bundle biasa.
///   2. Baca lewat NSDataAsset, tulis ke file sementara, load Entity(contentsOf:).
enum ModelAssetLoader {

    /// Muat entity dari asset bernama `name`. Mengembalikan nil bila gagal
    /// (pemanggil yang memutuskan placeholder-nya).
    static func load(named name: String) async -> Entity? {
        // 1. Coba langsung dari bundle (file .usdz/.usdc di luar asset catalog).
        if let entity = try? await Entity(named: name) {
            return entity
        }

        // 2. Baca data dari asset catalog lalu load lewat file sementara.
        if let data = NSDataAsset(name: name)?.data {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(name).usdc")
            do {
                try data.write(to: tempURL)
                return try await Entity(contentsOf: tempURL)
            } catch {
                print("ModelAssetLoader: gagal load '\(name)' — \(error)")
            }
        }
        return nil
    }

    /// Placeholder kotak abu-abu agar layar tidak kosong bila model gagal dimuat.
    static func placeholderBox() -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(size: [0.25, 0.08, 0.05], cornerRadius: 0.02),
            materials: [SimpleMaterial(color: .systemGray2, isMetallic: false)]
        )
    }
}

// MARK: - Lighting

/// Pencahayaan standar untuk scene 3D FishLog: key + fill light dari DEPAN
/// objek, plus Image-Based Lighting "studio" untuk efek glossy pada
/// material PBR (refleksi softbox putih).
enum SceneLighting {

    /// Key light + fill light dari arah depan (arah kamera, Z positif).
    static func makeStudioLights() -> [Entity] {
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 3500
        keyLight.look(at: .zero, from: [0.2, 0.25, 1.0], relativeTo: nil)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 1500
        fillLight.look(at: .zero, from: [-0.5, -0.1, 0.8], relativeTo: nil)

        return [keyLight, fillLight]
    }

    /// Entity pembawa ImageBasedLightComponent dari environment map studio.
    /// Nil bila pembuatan environment gagal (scene tetap hidup tanpa IBL).
    static func makeImageBasedLight() async -> Entity? {
        guard let image = makeStudioEnvironmentImage(),
              let environment = try? await EnvironmentResource(equirectangular: image)
        else { return nil }

        let entity = Entity()
        var ibl = ImageBasedLightComponent(source: .single(environment))
        ibl.intensityExponent = 1.0
        entity.components.set(ibl)
        return entity
    }

    /// Pasang ImageBasedLightReceiverComponent ke semua entity yang punya
    /// ModelComponent, supaya seluruh mesh model menerima cahaya IBL.
    static func attachReceiver(to entity: Entity, lightEntity: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: lightEntity))
        }
        entity.children.forEach { attachReceiver(to: $0, lightEntity: lightEntity) }
    }

    /// Gambar equirectangular sederhana yang meniru studio foto:
    /// langit-langit terang, lantai gelap, plus dua panel "softbox" putih
    /// di pita tengah (elevasi horizon) agar kilau datang dari arah depan.
    private static func makeStudioEnvironmentImage() -> CGImage? {
        let size = CGSize(width: 256, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Gradasi vertikal: terang di atas -> gelap di bawah.
            let colors = [
                UIColor(white: 0.95, alpha: 1).cgColor,
                UIColor(white: 0.45, alpha: 1).cgColor,
                UIColor(white: 0.12, alpha: 1).cgColor,
            ]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 0.55, 1.0]
            ) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }

            // Dua "softbox" putih — sumber highlight utama permukaan glossy.
            UIColor(white: 1.0, alpha: 0.95).setFill()
            ctx.fill(CGRect(x: 35, y: 46, width: 70, height: 28))
            ctx.fill(CGRect(x: 165, y: 52, width: 55, height: 20))
        }
        return image.cgImage
    }
}

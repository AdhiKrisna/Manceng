//
//  Model3DMotionManager.swift
//  Manceng
//
//  Membungkus CMMotionManager: membaca attitude (pitch & roll) device,
//  menghaluskannya dengan low-pass filter, lalu mem-publish nilainya
//  agar bisa diobservasi oleh SwiftUI (model 3D ikut bergerak saat
//  device dimiringkan).
//
//  Catatan permission: CMMotionManager.deviceMotion (accelerometer/gyro)
//  TIDAK membutuhkan NSMotionUsageDescription. Key itu hanya wajib untuk
//  data aktivitas fitness (CMPedometer / CMMotionActivityManager).
//

import Combine
import CoreMotion
import Foundation

final class Model3DMotionManager: ObservableObject {

    // Sengaja BUKAN @Published: nilai ini dibaca langsung oleh render loop
    // RealityKit tiap frame. Kalau di-publish, SwiftUI ikut re-render 60x/detik
    // dan itu yang bikin terasa lag.
    /// Rotasi device pada sumbu X (radian), relatif terhadap pose awal saat start.
    private(set) var pitch: Double = 0
    /// Rotasi device pada sumbu Z/Y (radian), relatif terhadap pose awal saat start.
    private(set) var roll: Double = 0

    /// Saklar gyro dari UI. Saat dimatikan, pitch/roll digiring halus ke 0
    /// (lewat low-pass yang sama, jadi tidak ada lompatan). Saat dinyalakan
    /// lagi, pose device saat itu dijadikan titik nol baru.
    /// (@Published aman di sini: nilainya hanya berubah saat user menggeser
    /// toggle, bukan tiap frame.)
    @Published var isEnabled = true {
        didSet {
            if isEnabled { recalibrate() }
        }
    }

    private let motionManager = CMMotionManager()

    /// Faktor low-pass filter (0...1). Makin kecil = makin halus tapi makin "berat"/lambat.
    private let smoothing = 0.12

    /// Pose referensi (titik nol), supaya nilai yang dipublish adalah DELTA
    /// kemiringan dari posisi awal user memegang device (bukan nilai absolut —
    /// kalau absolut, ikan akan langsung miring permanen karena orang memegang
    /// iPhone dalam posisi tegak, bukan rata meja).
    private var referencePitch: Double?
    private var referenceRoll: Double?

    /// Sample awal yang dikumpulkan untuk kalibrasi. Referensi diambil dari
    /// RATA-RATA beberapa sample pertama (bukan satu sample saja), supaya
    /// getaran tangan saat app baru dibuka tidak membuat titik nol meleset
    /// dan objek tampak miring sejak awal.
    private var calibrationSamples: [(pitch: Double, roll: Double)] = []
    private let calibrationSampleCount = 15 // ~0.25 detik @60Hz

    /// Timer untuk mock data di simulator (device motion tidak tersedia di sana).
    private var mockTimer: Timer?
    private var mockPhase = 0.0

    // MARK: - Lifecycle

    /// Mulai membaca device motion (~60 fps). Otomatis fallback ke mock di simulator.
    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            startMockUpdates()
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }

            // Fase kalibrasi: kumpulkan dulu beberapa sample, ambil rata-ratanya
            // sebagai titik nol. Selama fase ini pitch/roll ditahan di 0 agar
            // objek tampil tegak saat app pertama kali dibuka.
            if self.referencePitch == nil {
                self.calibrationSamples.append((attitude.pitch, attitude.roll))
                if self.calibrationSamples.count >= self.calibrationSampleCount {
                    let count = Double(self.calibrationSamples.count)
                    self.referencePitch = self.calibrationSamples.map(\.pitch).reduce(0, +) / count
                    self.referenceRoll = self.calibrationSamples.map(\.roll).reduce(0, +) / count
                    self.calibrationSamples.removeAll()
                }
                return
            }

            // Saat gyro dimatikan dari UI, target digiring ke 0 (ikan kembali
            // tegak dengan halus karena tetap melewati low-pass filter).
            let rawPitch = self.isEnabled ? attitude.pitch - (self.referencePitch ?? 0) : 0
            let rawRoll = self.isEnabled ? attitude.roll - (self.referenceRoll ?? 0) : 0

            // Low-pass filter sederhana: nilai baru = nilai lama + α * (target - nilai lama).
            // Meredam jitter sensor sehingga gerakan model terasa halus.
            self.pitch += self.smoothing * (rawPitch - self.pitch)
            self.roll += self.smoothing * (rawRoll - self.roll)
        }
    }

    /// Hentikan semua update (panggil di onDisappear agar hemat baterai).
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        mockTimer?.invalidate()
        mockTimer = nil
    }

    /// Jadikan pose device saat ini sebagai titik nol baru
    /// (kalibrasi ulang dengan rata-rata sample, sama seperti saat start).
    func recalibrate() {
        referencePitch = nil
        referenceRoll = nil
        calibrationSamples.removeAll()
    }

    // MARK: - Fallback simulator

    /// Di simulator tidak ada sensor gerak, jadi kita animasikan gelombang sinus
    /// pelan agar efek "spasial" tetap terlihat saat development.
    private func startMockUpdates() {
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.mockPhase += 1.0 / 60.0
            // Hormati saklar gyro juga di simulator.
            let targetPitch = self.isEnabled ? 0.10 * sin(self.mockPhase * 0.8) : 0
            let targetRoll = self.isEnabled ? 0.18 * sin(self.mockPhase * 0.5) : 0
            self.pitch += self.smoothing * (targetPitch - self.pitch)
            self.roll += self.smoothing * (targetRoll - self.roll)
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        mockTimer?.invalidate()
    }
}

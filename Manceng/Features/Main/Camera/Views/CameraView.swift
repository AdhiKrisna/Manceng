//
//  CameraView.swift
//  Manceng
//
//  Created by Made Vidyatma Adhi Krisna on 10/06/26.
//

import SwiftUI

struct CameraView: View {
    var body: some View {
        ContentUnavailableView("Camera", systemImage: "camera.fill", description: Text("Coming soon"))
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        CameraView()
    }
}

//
//  CustomAICameraView.swift
//  track yo calories
//

import SwiftUI
import AVFoundation
import PhotosUI

struct CustomAICameraView: View {
    var onPhotoCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cameraModel = AICameraModel()
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        ZStack {
            // Full-screen Camera Viewfinder
            #if targetEnvironment(simulator)
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("Camera not available on Simulator")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(14)
                }
            }
            #else
            AICameraPreviewView(session: cameraModel.session)
                .ignoresSafeArea()
            #endif
            
            // Top and Bottom Controls Overlay
            VStack(spacing: 0) {
                topBar
                
                Spacer()
                
                zoomBar
                
                bottomShutterBar
            }
        }
        .onAppear {
            cameraModel.startSession()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
        .onChange(of: cameraModel.capturedImage) { _, image in
            if let img = image {
                onPhotoCaptured(img)
                dismiss()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        onPhotoCaptured(img)
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var topBar: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                Text("AI Food Vision")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            
            Spacer()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cameraModel.toggleFlash()
            }) {
                Image(systemName: cameraModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cameraModel.isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var zoomBar: some View {
        HStack(spacing: 12) {
            ForEach(cameraModel.availableZoomFactors, id: \.self) { factor in
                ZoomPillButton(
                    factor: factor,
                    isSelected: cameraModel.currentZoomFactor == factor,
                    action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        cameraModel.setZoom(factor: factor)
                    }
                )
            }
        }
        .padding(.bottom, 24)
    }
    
    private var bottomShutterBar: some View {
        HStack {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                cameraModel.capturePhoto()
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 66, height: 66)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cameraModel.switchCamera()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 44)
    }
}

// MARK: - Zoom Pill Button Subview
struct ZoomPillButton: View {
    let factor: CGFloat
    let isSelected: Bool
    let action: () -> Void
    
    private var title: String {
        factor == 0.5 ? "0.5×" : "\(Int(factor))×"
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .yellow : .white)
                .frame(width: 42, height: 42)
                .background(isSelected ? Color.black.opacity(0.65) : Color.black.opacity(0.35))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - AICameraPreviewView
struct AICameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - AICameraModel
final class AICameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage? = nil
    @Published var isFlashOn: Bool = false
    @Published var currentZoomFactor: CGFloat = 0.5
    @Published var availableZoomFactors: [CGFloat] = [0.5, 1.0, 2.0]
    
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var isUsingUltraWide: Bool = false
    private let sessionQueue = DispatchQueue(label: "app.trackyocalories.aicamera")
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // 1. Try to default to Ultra-Wide (0.5x) camera
            var selectedDevice: AVCaptureDevice? = nil
            if let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
                selectedDevice = ultraWide
                self.isUsingUltraWide = true
            } else if let tripleCamera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
                selectedDevice = tripleCamera
            } else if let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                selectedDevice = dualWide
            } else if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                selectedDevice = wide
            }
            
            if let device = selectedDevice,
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentDevice = device
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.commitConfiguration()
            
            // Set default zoom to minimum (0.5x ultra-wide)
            self.applyDefaultZoom()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    private func applyDefaultZoom() {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = device.minAvailableVideoZoomFactor
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.currentZoomFactor = 0.5
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    func setZoom(factor: CGFloat) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.maxAvailableVideoZoomFactor, 5.0)
            
            var targetZoom: CGFloat = 1.0
            if factor == 0.5 {
                targetZoom = minZoom
            } else if factor == 1.0 {
                targetZoom = max(minZoom, 1.0)
            } else if factor == 2.0 {
                targetZoom = min(maxZoom, max(minZoom, 2.0))
            }
            
            device.videoZoomFactor = targetZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.currentZoomFactor = factor
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition)
            
            guard let device = newDevice, let newInput = try? AVCaptureDeviceInput(device: device) else { return }
            
            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentDevice = device
            } else {
                self.session.addInput(currentInput)
            }
            self.session.commitConfiguration()
        }
    }
    
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = AVCapturePhotoSettings()
            if self.isFlashOn && self.currentDevice?.hasFlash == true {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

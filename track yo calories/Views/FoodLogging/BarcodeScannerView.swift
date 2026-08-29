//
//  BarcodeScannerView.swift
//  track yo calories
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @ObservedObject var dataStore: DataStore
    var targetMeal: MealType
    var targetDate: Date
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isFlashlightOn: Bool = false
    @State private var isLoadingProduct: Bool = false
    @State private var errorMessage: String? = nil
    @State private var scannedFood: FoodItem? = nil
    @State private var manualBarcodeInput: String = ""
    @State private var showManualInputSheet: Bool = false
    @State private var isLaserAnimating: Bool = false
    
    var body: some View {
        ZStack {
            // Camera Preview / Simulator Fallback
            #if targetEnvironment(simulator)
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("Camera Scanner not available on Simulator")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Install on your iPhone or enter barcode manually below")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: { showManualInputSheet = true }) {
                    Label("Enter Barcode Manually", systemImage: "keyboard")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(14)
                }
                .padding(.top, 8)
            }
            #else
            CameraScannerRepresentable(
                isFlashlightOn: $isFlashlightOn,
                onBarcodeScanned: { code in
                    handleScannedCode(code)
                }
            )
            .ignoresSafeArea()
            #endif
            
            // Darkened Vignette Overlay with transparent cutout for scanning frame
            VStack(spacing: 0) {
                // Top Header Controls
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Barcode Scanner")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isFlashlightOn.toggle()
                    }) {
                        Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isFlashlightOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Alignment Pill
                HStack(spacing: 6) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 14))
                    Text("Align barcode inside frame")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.top, 20)
                
                Spacer()
                
                // Scanner Frame with Animated Laser
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 290, height: 190)
                    
                    // Smooth Modern Laser Line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0), Color.orange, Color.orange.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 270, height: 3)
                        .shadow(color: .orange, radius: 6)
                        .offset(y: isLaserAnimating ? 80 : -80)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: isLaserAnimating
                        )
                    
                    // Modern Rounded Corner Brackets
                    ModernScannerCorners()
                        .stroke(Color.orange, lineWidth: 4.5)
                        .frame(width: 290, height: 190)
                }
                
                Spacer()
                
                // Bottom Action Bar: Type Barcode
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showManualInputSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Type Barcode Manually")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                }
                .padding(.bottom, 48)
            }
            
            // Loading Overlay
            if isLoadingProduct {
                ZStack {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Looking up nutrition info...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }
        }
        .onAppear {
            isLaserAnimating = true
        }
        .sheet(item: $scannedFood) { food in
            FoodDetailView(
                food: food,
                dataStore: dataStore,
                targetMeal: targetMeal,
                targetDate: targetDate,
                onLogged: {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showManualInputSheet) {
            manualInputSheet
        }
        .alert("Product Lookup", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Handle Scanned Barcode
    private func handleScannedCode(_ code: String) {
        guard !isLoadingProduct else { return }
        
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isLoadingProduct = true
        
        Task {
            // 1. Check local offline database first
            let localMatches = LocalFoodDatabaseService.shared.search(query: cleaned)
            if let matched = localMatches.first(where: { $0.barcode == cleaned }) {
                await MainActor.run {
                    isLoadingProduct = false
                    scannedFood = matched
                }
                return
            }
            
            // 2. Fetch from live OpenFoodFacts API
            do {
                if let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: cleaned) {
                    await MainActor.run {
                        isLoadingProduct = false
                        scannedFood = product
                    }
                } else {
                    await MainActor.run {
                        isLoadingProduct = false
                        errorMessage = "Barcode '\(cleaned)' not found in offline or online database. You can add it manually via Quick Add."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingProduct = false
                    errorMessage = "Unable to connect to database. Please check your internet connection."
                }
            }
        }
    }
    
    // MARK: - Manual Barcode Input Sheet
    private var manualInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter 8, 12, or 13-digit barcode", text: $manualBarcodeInput)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Barcode Number")
                } footer: {
                    Text("e.g. 7613035848521 (Swiss/EU EAN) or 073852002167 (US UPC)")
                }
            }
            .navigationTitle("Manual Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manualBarcodeInput = ""
                        showManualInputSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        let code = manualBarcodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        manualBarcodeInput = ""
                        showManualInputSheet = false
                        handleScannedCode(code)
                    }
                    .disabled(manualBarcodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(240)])
    }
}

// MARK: - Modern Scanner Corner Brackets
struct ModernScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 32
        let radius: CGFloat = 16
        
        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        
        // Top Right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        
        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        
        // Bottom Left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        
        return path
    }
}

// MARK: - AVCapture Video Preview Representable
#if !targetEnvironment(simulator)
struct CameraScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isFlashlightOn: Bool
    var onBarcodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.toggleFlashlight(on: isFlashlightOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }
    
    class Coordinator: NSObject, BarcodeScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void
        
        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }
        
        func didFindBarcode(_ code: String) {
            onBarcodeScanned(code)
        }
    }
}

protocol BarcodeScannerViewControllerDelegate: AnyObject {
    func didFindBarcode(_ code: String)
}

final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedCode: String?
    private var lastScanTime: Date = .distantPast
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.stopRunning()
            }
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .dataMatrix
            ]
        } else {
            return
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.captureSession = session
        self.previewLayer = preview
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        
        // Debounce scan events within 2.0s for the same barcode
        if stringValue == lastScannedCode && Date().timeIntervalSince(lastScanTime) < 2.0 {
            return
        }
        
        lastScannedCode = stringValue
        lastScanTime = Date()
        
        delegate?.didFindBarcode(stringValue)
    }
    
    func toggleFlashlight(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
#endif

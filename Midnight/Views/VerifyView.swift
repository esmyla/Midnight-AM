import SwiftUI
import PhotosUI

/// Submit proof. Screenshot or photo is judged by the vision model; manual is one confirm for low stakes.
struct VerifyView: View {
    @EnvironmentObject var engine: CommitmentEngine
    @Environment(\.dismiss) private var dismiss
    let commitment: Commitment

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var checking = false
    @State private var verdict: VerificationVerdict?
    @State private var error: String?
    @State private var passed = false

    var body: some View {
        ZStack {
            Color.clear.background(MidnightBackground(tint: Theme.accent))
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    IconButton(system: "xmark") { dismiss() }
                    Spacer()
                }
                Text("Prove it.")
                    .display(36)
                if commitment.verification != .manual {
                    Text(prompt)
                        .font(.system(.body))
                        .foregroundStyle(Theme.text2)
                }

                if commitment.verification == .manual {
                    Spacer()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("I DID IT").eyebrow()
                        Text(commitment.title).display(34)
                    }
                    Spacer()
                    Button {
                        Haptics.notify(.success)
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            engine.complete(note: "Marked done manually")
                        }
                    } label: { Label("Yes, I finished it", systemImage: "checkmark.seal.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: image == nil ? [6, 6] : [])))
                        if let image {
                            Image(uiImage: image)
                                .resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(8)
                                .overlay { if checking { ScanLine() .padding(8) } }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: commitment.verification == .screenshot ? "rectangle.on.rectangle" : "camera")
                                    .font(.system(size: 34, weight: .light))
                                Text(commitment.verification == .screenshot ? "Your screenshot goes here" : "Your photo goes here")
                                    .font(.system(.subheadline))
                            }
                            .foregroundStyle(Theme.text3)
                        }
                    }
                    .frame(maxHeight: 340)
                    .frame(minHeight: 220)
                    .animation(.smooth, value: image == nil)

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(commitment.verification == .screenshot ? "Choose screenshot" : "Choose photo",
                                  systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        if commitment.verification == .photo, UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { showCamera = true } label: { Image(systemName: "camera.fill").frame(width: 56) }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }

                    if let verdict {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: verdict.satisfied ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(verdict.satisfied ? Theme.mint : Theme.amber)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verdict.satisfied ? "Verified" : "Not convinced")
                                    .font(.system(.headline))
                                Text(verdict.reason)
                                    .font(.system(.footnote))
                                    .foregroundStyle(Theme.text2)
                            }
                        }
                        .glass(16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let error {
                        Text(error).font(.system(.footnote)).foregroundStyle(Theme.rose)
                    }

                    Spacer()

                    Button(action: check) {
                        HStack(spacing: 10) {
                            if checking { ProgressView().tint(.black) }
                            Text(checking ? "Checking…" : "Verify")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(image == nil || checking || passed)
                }
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    withAnimation(.smooth) { image = UIImage(data: data); verdict = nil; error = nil }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in withAnimation(.smooth) { image = img; verdict = nil; error = nil } }.ignoresSafeArea()
        }
    }

    private var prompt: String {
        let q = commitment.quantityLine.isEmpty ? "" : " (\(commitment.quantityLine))"
        switch commitment.verification {
        case .screenshot: return "A screenshot that shows you finished: \(commitment.taskDescription)\(q)."
        case .photo: return "A photo that proves it: \(commitment.taskDescription)\(q)."
        case .manual: return "Low-stakes promise. Your word is the proof."
        }
    }

    private func check() {
        guard let image else { return }
        Haptics.impact(.light)
        withAnimation(.smooth) { checking = true; error = nil; verdict = nil }
        engine.markAwaitingVerification()
        Task {
            do {
                let v = try await VerificationService.verify(image: image, for: commitment)
                withAnimation(.smooth) { checking = false; verdict = v }
                if v.satisfied && v.confidence >= 0.6 {
                    Haptics.notify(.success)
                    withAnimation(.smooth) { passed = true }
                    try? await Task.sleep(for: .milliseconds(1100))
                    dismiss()
                    try? await Task.sleep(for: .milliseconds(450))
                    engine.complete(note: v.reason)
                } else {
                    Haptics.notify(.error)
                    engine.verificationFailed()
                }
            } catch {
                withAnimation(.smooth) { checking = false; self.error = error.localizedDescription }
                engine.verificationFailed()
            }
        }
    }
}

/// A light bar sweeping the image while the model looks at it.
private struct ScanLine: View {
    @State private var down = false
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Theme.accent2.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
                .shadow(color: Theme.accent2.opacity(0.8), radius: 10)
                .offset(y: down ? geo.size.height - 3 : 0)
                .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { down = true } }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

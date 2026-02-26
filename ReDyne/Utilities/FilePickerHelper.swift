import UIKit
import UniformTypeIdentifiers
import SwiftUI

/// A utility helper for presenting file pickers that respects the Enhanced/Legacy file picker mode
class FilePickerHelper {
    
    /// Present a file picker from any view controller, automatically using the appropriate mode
    /// - Parameters:
    ///   - types: The content types to allow (e.g., [.json], [.item])
    ///   - from: The view controller presenting the picker
    ///   - onPick: Completion handler called when files are selected
    static func presentFilePicker(
        types: [UTType],
        from viewController: UIViewController,
        onPick: @escaping ([URL]) -> Void
    ) {
        if UserDefaults.standard.useLegacyFilePicker {
            // Use SwiftUI-based picker for Legacy mode (works with EnhancedFilePicker)
            presentEnhancedPicker(types: types, from: viewController, onPick: onPick)
        } else {
            // Use standard UIKit picker for Modern mode
            presentStandardPicker(types: types, from: viewController, onPick: onPick)
        }
    }
    
    /// Present the Enhanced (Legacy) file picker using SwiftUI approach
    private static func presentEnhancedPicker(
        types: [UTType],
        from viewController: UIViewController,
        onPick: @escaping ([URL]) -> Void
    ) {
        // Get the scene delegate
        guard let windowScene = viewController.view.window?.windowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate else {
            print("FilePickerHelper: No scene delegate available, falling back to standard picker")
            presentStandardPicker(types: types, from: viewController, onPick: onPick)
            return
        }
        
        let sceneDelegateWrapper = SceneDelegateWrapper(sceneDelegate: sceneDelegate)
        
        // Create a SwiftUI hosting controller with the document picker
        let swiftUIView = FilePickerHelperView(
            types: types,
            sceneDelegateWrapper: sceneDelegateWrapper,
            onPick: onPick
        )
        
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        
        viewController.present(hostingController, animated: false) {
            // Trigger the picker presentation after the hosting controller is shown
            DispatchQueue.main.async {
                hostingController.dismiss(animated: false)
            }
        }
    }
    
    /// Present the standard UIKit file picker
    private static func presentStandardPicker(
        types: [UTType],
        from viewController: UIViewController,
        onPick: @escaping ([URL]) -> Void
    ) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        
        let delegate = FilePickerDelegate(onPick: onPick)
        picker.delegate = delegate
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        // Retain the delegate
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        viewController.present(picker, animated: true)
    }
}

// MARK: - Delegate Helper

private class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onPick: ([URL]) -> Void
    
    init(onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("FilePickerHelper: Document picker cancelled")
    }
}

// MARK: - SwiftUI View Helper

private struct FilePickerHelperView: View {
    let types: [UTType]
    @ObservedObject var sceneDelegateWrapper: SceneDelegateWrapper
    @State private var isPresented = true
    let onPick: ([URL]) -> Void
    
    var body: some View {
        Color.clear
            .documentPicker(
                isPresented: $isPresented,
                types: types,
                multiple: false,
                sceneDelegateWrapper: sceneDelegateWrapper,
                onPick: onPick,
                onDismiss: {}
            )
            .onAppear {
                print("FilePickerHelperView appeared")
                // The documentPicker modifier will handle presentation
            }
    }
}

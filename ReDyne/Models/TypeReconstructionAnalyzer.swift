import Foundation

@objc class TypeReconstructionAnalyzer: NSObject {
    @objc static func analyze(binaryPath: String) -> TypeReconstructionResultsObject? {
        guard !binaryPath.isEmpty else {
            return nil
        }

        guard let resultPtr = c_reconstruct_types_from_binary(binaryPath) else {
            return nil
        }
        defer {
            c_free_reconstruction_result(resultPtr)
        }

        let result = resultPtr.pointee
        guard let typesPtr = result.types, result.type_count > 0 else {
            return TypeReconstructionResultsObject(types: [])
        }

        let buffer = UnsafeBufferPointer(start: typesPtr, count: Int(result.type_count))
        let types: [TypeReconstructedTypeObject] = buffer.compactMap { entry in
            guard let namePtr = entry.name else { return nil }
            let name = String(cString: namePtr)
            if name.isEmpty { return nil }

            let category = categoryString(for: entry.category)
            return TypeReconstructedTypeObject(
                name: name,
                category: category,
                size: Int(entry.size),
                address: entry.address,
                confidence: entry.confidence
            )
        }

        return TypeReconstructionResultsObject(types: types)
    }

    private static func categoryString(for category: c_type_category_t) -> String {
        switch category {
        case C_TYPE_CATEGORY_CLASS:
            return "class"
        case C_TYPE_CATEGORY_STRUCT:
            return "struct"
        case C_TYPE_CATEGORY_ENUM:
            return "enum"
        case C_TYPE_CATEGORY_PROTOCOL:
            return "protocol"
        default:
            return "unknown"
        }
    }
}

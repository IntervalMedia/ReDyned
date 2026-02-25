import Foundation

struct FunctionNameImportEntry: Equatable {
    let address: UInt64
    let name: String
}

enum FunctionNameImportError: Error, LocalizedError {
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return message
        }
    }
}

final class FunctionNameImportService {
    static func parse(data: Data) throws -> [FunctionNameImportEntry] {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = jsonObject as? [String: Any] else {
            throw FunctionNameImportError.invalidFormat("Root JSON must be an object.")
        }
        guard let functionsArray = json["Functions"] as? [[String: Any]] else {
            throw FunctionNameImportError.invalidFormat("Missing \"Functions\" array.")
        }

        var entries: [FunctionNameImportEntry] = []
        entries.reserveCapacity(functionsArray.count)

        for (index, item) in functionsArray.enumerated() {
            guard let name = item["Name"] as? String, !name.isEmpty else {
                throw FunctionNameImportError.invalidFormat("Missing or empty Name at index \(index).")
            }

            let addressValue = item["Address"]
            let address: UInt64
            if let number = addressValue as? NSNumber {
                if number.int64Value < 0 {
                    throw FunctionNameImportError.invalidFormat("Address must be non-negative at index \(index).")
                }
                address = number.uint64Value
            } else if let string = addressValue as? String, let parsed = UInt64(string) {
                address = parsed
            } else {
                throw FunctionNameImportError.invalidFormat("Invalid Address at index \(index).")
            }

            entries.append(FunctionNameImportEntry(address: address, name: name))
        }

        return entries
    }

    static func apply(entries: [FunctionNameImportEntry], to functions: [FunctionModel]) -> [FunctionModel] {
        var byAddress: [UInt64: FunctionModel] = [:]
        byAddress.reserveCapacity(functions.count + entries.count)

        for function in functions {
            byAddress[function.startAddress] = function
        }

        for entry in entries {
            if let existing = byAddress[entry.address] {
                existing.name = entry.name
                byAddress[entry.address] = existing
            } else {
                let newFunction = FunctionModel()
                newFunction.name = entry.name
                newFunction.startAddress = entry.address
                newFunction.endAddress = entry.address
                newFunction.instructionCount = 0
                byAddress[entry.address] = newFunction
            }
        }

        return byAddress.values.sorted { $0.startAddress < $1.startAddress }
    }
}

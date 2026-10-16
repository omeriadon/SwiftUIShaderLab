import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ShaderLibraryModel {
    private(set) var shaders: [ShaderDefinition] = []
    var values: [Float] = []

    func load() {
        guard shaders.isEmpty,
              let url = Bundle.main.url(forResource: "ParametersData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(ShaderDocument.self, from: data) else {
            return
        }

        shaders = document.shaders
        values = shaders.first?.params.map(\.defaultValue) ?? []
    }

    func shader(for definition: ShaderDefinition, size: CGSize, time: Float, touchPoint: UnitPoint) -> Shader {
        var arguments: [Shader.Argument] = [.float2(CGSize(width: size.width, height: size.height))]

        if definition.animated {
            arguments.append(.float(time))
        }

        for parameter in definition.params {
            if parameter.type == .point {
                arguments.append(.float2(CGSize(width: size.width * touchPoint.x, height: size.height * touchPoint.y)))
            } else {
                let index = definition.params.firstIndex { $0.label == parameter.label } ?? 0
                let value = values.indices.contains(index) ? values[index] : parameter.defaultValue
                arguments.append(.float(value))
            }
        }

        return Shader(
            function: ShaderLibrary.default[dynamicMember: definition.metal],
            arguments: arguments
        )
    }

    func modifierCall(for definition: ShaderDefinition, values: [Float], touchPoint: UnitPoint) -> String {
        let arguments = definition.params.enumerated().map { index, parameter in
            if parameter.type == .point {
                return "\(parameter.label): UnitPoint(x: \(String(format: "%.2f", touchPoint.x)), y: \(String(format: "%.2f", touchPoint.y)))"
            }

            let value = values.indices.contains(index) ? values[index] : parameter.defaultValue
            return "\(parameter.label): \(String(format: "%.2f", value))"
        }

        return ".\(definition.modifier)(\(arguments.joined(separator: ", ")))"
    }
}

struct ShaderDocument: Codable {
    let shaders: [ShaderDefinition]
}

struct ShaderDefinition: Codable, Identifiable {
    let modifier: String
    let metal: String
    let title: String
    let animated: Bool
    let params: [ShaderParameter]

    var id: String { modifier }
}

struct ShaderParameter: Codable {
    let label: String
    let type: ParameterType
    let min: Float
    let max: Float
    let defaultValue: Float

    enum CodingKeys: String, CodingKey {
        case label
        case type
        case min
        case max
        case defaultValue = "default"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(ParameterType.self, forKey: .type)

        let decodedDefault = try container.decodeIfPresent(Float.self, forKey: .defaultValue)
        defaultValue = decodedDefault ?? (type == .point ? 0 : 1)
        min = try container.decodeIfPresent(Float.self, forKey: .min) ?? 0
        max = try container.decodeIfPresent(Float.self, forKey: .max) ?? Swift.max(defaultValue * 2, 1)
    }
}

enum ParameterType: String, Codable {
    case float
    case point
}

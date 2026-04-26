import SwiftUI
import VocraCore

struct SettingsView: View {
  @State private var baseURL = APIConfiguration.default.baseURL.absoluteString
  @State private var model = APIConfiguration.default.model
  @State private var temperature = APIConfiguration.default.temperature
  @State private var timeout = APIConfiguration.default.timeoutSeconds
  @State private var apiKey = ""

  var body: some View {
    Form {
      Section("API") {
        TextField("Base URL", text: $baseURL)
        TextField("Model", text: $model)
        SecureField("API Key", text: $apiKey)

        HStack {
          Text("Temperature")
          Slider(value: $temperature, in: 0...2, step: 0.1)
          Text(temperature.formatted(.number.precision(.fractionLength(1))))
            .monospacedDigit()
            .frame(width: 36, alignment: .trailing)
        }

        HStack {
          Text("Timeout")
          Stepper("\(Int(timeout)) seconds", value: $timeout, in: 5...120, step: 5)
        }

        Button("Test Connection") {}
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 520)
  }
}

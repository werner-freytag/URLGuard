import SwiftUI

// MARK: - ViewModels

class URLInputViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var error: String? = nil
    
    func validate() -> String? {
        let sanitized = sanitizeURLString(urlString)
        
        if sanitized.isEmpty {
            return "URL darf nicht leer sein"
        }
        
        guard let url = URL(string: sanitized) else {
            return "URL ist ungültig"
        }
        
        guard url.isValidForMonitoring else {
            return "URL ist fehlerhaft"
        }
        
        return nil
    }
    
    func performValidation() {
        error = validate()
    }
    
    func clearError() {
        error = nil
    }
}

class IntervalInputViewModel: ObservableObject {
    @Published var interval: Double = 60
    @Published var error: String? = nil
    
    func validate() -> String? {
        if interval < 1 {
            return "Intervall muss mindestens 1 Sekunde betragen"
        }
        
        return nil
    }
    
    func performValidation() {
        error = validate()
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - URL Input View

struct URLInputView: View {
    @ObservedObject var viewModel: URLInputViewModel
    let onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool
    
    init(viewModel: URLInputViewModel, onSubmit: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("URL")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("https://example.com", text: $viewModel.urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .onChange(of: viewModel.urlString) {
                    viewModel.clearError()
                }
                .onSubmit {
                    onSubmit?()
                }
                .onAppear {
                    isFocused = true
                }
            
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Interval Input View

struct IntervalInputView: View {
    @ObservedObject var viewModel: IntervalInputViewModel
    
    init(viewModel: IntervalInputViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Intervall (Sekunden)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("", value: $viewModel.interval, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .onChange(of: viewModel.interval) {
                        viewModel.clearError()
                    }
                
                Stepper("", value: $viewModel.interval, in: 1...3600, step: 1)
                    .labelsHidden()
            }
            
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Previews

#Preview("URLInputView - Valid") {
    let viewModel = URLInputViewModel()
    viewModel.urlString = "https://example.com"
    
    return URLInputView(viewModel: viewModel)
        .padding()
}

#Preview("URLInputView - Invalid") {
    let viewModel = URLInputViewModel()
    viewModel.urlString = "invalid-url"
    viewModel.performValidation()
    
    return URLInputView(viewModel: viewModel)
        .padding()
}

#Preview("IntervalInputView - Valid") {
    let viewModel = IntervalInputViewModel()
    viewModel.interval = 60
    
    return IntervalInputView(viewModel: viewModel)
        .padding()
}

#Preview("IntervalInputView - Invalid") {
    let viewModel = IntervalInputViewModel()
    viewModel.interval = 0.5
    viewModel.performValidation()
    
    return IntervalInputView(viewModel: viewModel)
        .padding()
} 

import SwiftUI

enum DocmostlyTextInputAutocapitalization {
    case never
    case words
    case sentences
}

enum DocmostlyKeyboardType {
    case url
    case emailAddress
    case numberPad
}

enum DocmostlyTextContentType {
    case url
    case username
    case password
}

extension View {
    @ViewBuilder
    func docmostlyTextInputAutocapitalization(_ value: DocmostlyTextInputAutocapitalization) -> some View {
        #if os(iOS)
        switch value {
        case .never:
            textInputAutocapitalization(.never)
        case .words:
            textInputAutocapitalization(.words)
        case .sentences:
            textInputAutocapitalization(.sentences)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func docmostlyKeyboardType(_ value: DocmostlyKeyboardType) -> some View {
        #if os(iOS)
        switch value {
        case .url:
            keyboardType(.URL)
        case .emailAddress:
            keyboardType(.emailAddress)
        case .numberPad:
            keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func docmostlyTextContentType(_ value: DocmostlyTextContentType) -> some View {
        #if os(iOS)
        switch value {
        case .url:
            textContentType(.URL)
        case .username:
            textContentType(.username)
        case .password:
            textContentType(.password)
        }
        #else
        self
        #endif
    }
}

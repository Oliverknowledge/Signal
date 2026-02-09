import Foundation

struct APIConfig {
    static let baseURL: String = {
        #if DEBUG
        return "https://signal-backend-seven.vercel.app"
        #else
        return "https://signal-backend-seven.vercel.app"
        #endif
    }()
}

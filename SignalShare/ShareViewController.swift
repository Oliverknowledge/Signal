import UIKit
import UniformTypeIdentifiers

// MARK: - Share Extension Theme Colors (matches main app Theme.Colors)
private struct ShareThemeColors {
    static let primaryBackground = UIColor(hex: "FFFFFF")
    static let secondaryBackground = UIColor(hex: "F2F6FF")
    static let contentSurface = UIColor(hex: "FAFCFF")
    static let primaryAccent = UIColor(hex: "0D85FF")
    static let textPrimary = UIColor(hex: "0F172A")
    static let textSecondary = UIColor(hex: "475569")
    static let textMuted = UIColor(hex: "64748B")
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255.0,
                  green: CGFloat(g) / 255.0,
                  blue: CGFloat(b) / 255.0,
                  alpha: CGFloat(a) / 255.0)
    }
}

class ShareViewController: UIViewController {
    private let appGroupSuite = "group.OliverStevenson.Signal"
    
    // MARK: - UI Components (Same as before but with proper setup)
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ShareThemeColors.contentSurface
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "waveform")
        imageView.tintColor = ShareThemeColors.primaryAccent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Saved to Signal"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = ShareThemeColors.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Queued for analysis - open Signal to process."
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = ShareThemeColors.textMuted
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let extraLabel: UILabel = {
        let label = UILabel()
        label.text = "You'll find it in Home -> Ready to review or Library."
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = ShareThemeColors.textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = ShareThemeColors.primaryAccent
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.progressTintColor = ShareThemeColors.primaryAccent
        bar.trackTintColor = ShareThemeColors.secondaryBackground
        bar.progress = 0.0
        return bar
    }()
    
    private let vstack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(ShareThemeColors.primaryAccent, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateCopyForOnboardingState()
        extractSharedContent()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Transparent background with blur
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        // Add container
        view.addSubview(containerView)
        
        containerView.addSubview(vstack)
        vstack.addArrangedSubview(iconImageView)
        vstack.addArrangedSubview(titleLabel)
        vstack.addArrangedSubview(subtitleLabel)
        vstack.addArrangedSubview(extraLabel)
        vstack.setCustomSpacing(16, after: extraLabel)
        vstack.addArrangedSubview(progressView)
        vstack.addArrangedSubview(progressBar)
        vstack.setCustomSpacing(16, after: progressBar)
        vstack.addArrangedSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            // Container pinned to edges with comfortable margins
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Stack fills container with padding
            vstack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            vstack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            vstack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            vstack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            // Icon size
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),

            // Progress bar height
            progressBar.heightAnchor.constraint(equalToConstant: 2),
            progressBar.leadingAnchor.constraint(equalTo: vstack.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: vstack.trailingAnchor),

            // Cancel button height
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        progressView.startAnimating()
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.title = "Cancel"
            config.baseForegroundColor = ShareThemeColors.primaryAccent
            config.baseBackgroundColor = ShareThemeColors.secondaryBackground
            cancelButton.configuration = config
            cancelButton.setTitle(nil, for: .normal)
        }
    }

    private func updateCopyForOnboardingState() {
        let canProcess = appCanProcessQueuedItems()
        titleLabel.text = "Saved to Signal"
        if canProcess {
            subtitleLabel.text = "Queued for analysis - open Signal to process."
        } else {
            subtitleLabel.text = "Finish onboarding in Signal to start analysis."
        }
    }

    private func appCanProcessQueuedItems() -> Bool {
        guard let userDefaults = UserDefaults(suiteName: appGroupSuite) else { return false }
        let hasOnboarded = userDefaults.bool(forKey: "hasOnboarded")
        let selectedGoalId = userDefaults.string(forKey: "selectedGoalId")
        return hasOnboarded && selectedGoalId != nil
    }
    
    // MARK: - Content Extraction
    private func extractSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments, !providers.isEmpty else {
            completeWithError()
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            loadURL(from: provider)
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            loadText(from: provider, type: UTType.plainText.identifier)
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
            loadText(from: provider, type: UTType.text.identifier)
            return
        }

        completeWithError()
    }

    private func loadURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let url = item as? URL {
                self.processURL(url.absoluteString)
            } else if let urlString = item as? String {
                self.processURL(urlString)
            } else {
                self.completeWithError()
            }
        }
    }

    private func loadText(from provider: NSItemProvider, type: String) {
        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let text = item as? String, let url = self.extractURL(from: text) {
                self.processURL(url)
            } else {
                self.completeWithError()
            }
        }
    }
    
    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url?.absoluteString
    }
    
    // MARK: - Processing
    private func processURL(_ urlString: String) {
        guard isValidURL(urlString) else {
            DispatchQueue.main.async {
                self.subtitleLabel.text = "Invalid URL"
                self.progressView.stopAnimating()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.completeWithError()
            }
            return
        }
        
        DispatchQueue.main.async {
            self.updateCopyForOnboardingState()
            self.progressBar.setProgress(0.6, animated: true)
        }
        sendToMainApp(url: urlString)
    }
    
    private func sendToMainApp(url: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupSuite) else {
            DispatchQueue.main.async {
                self.subtitleLabel.text = "Could not save to shared queue."
                self.progressView.stopAnimating()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.completeWithError()
            }
            return
        }

        var pendingURLs = userDefaults.stringArray(forKey: "pendingAnalysis") ?? []
        pendingURLs.append(url)
        #if DEBUG
        print("[ShareExtension] Added URL to queue. New count: \(pendingURLs.count)")
        #endif
        userDefaults.set(pendingURLs, forKey: "pendingAnalysis")
        
        DispatchQueue.main.async {
            self.progressView.stopAnimating()
            self.progressBar.setProgress(1.0, animated: true)
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "SignalShareExtension", code: -1, userInfo: nil))
    }
    
    private func completeWithError() {
        DispatchQueue.main.async {
            self.extensionContext?.cancelRequest(withError: NSError(domain: "SignalShareExtension", code: -1, userInfo: nil))
        }
    }
}

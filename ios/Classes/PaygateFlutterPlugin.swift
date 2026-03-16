import Flutter
import UIKit
import WebKit
import PaygateSDK

public class PaygateFlutterPlugin: NSObject, FlutterPlugin {
    private var pendingResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.paygate.flutter/sdk", binaryMessenger: registrar.messenger())
        let instance = PaygateFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(result: result)
        case "launch":
            handleLaunch(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(result: @escaping FlutterResult) {
        Task {
            await StoreKitManager.shared.start()
            await StoreKitManager.shared.loadPurchasedProducts()
            let purchased = await Array(StoreKitManager.shared.purchasedProductIDs)
            result(purchased)
        }
    }

    private func handleLaunch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let htmlContent = args["htmlContent"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "htmlContent is required", details: nil))
            return
        }

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController?.topMostViewController() else {
            result(FlutterError(code: "NO_VC", message: "No view controller available", details: nil))
            return
        }

        let bounces = args["bounces"] as? Bool ?? false
        let presentationStyle = args["presentationStyle"] as? String ?? "sheet"
        let productIdMap = args["productIdMap"] as? [String: String] ?? [:]

        self.pendingResult = result

        let paygateVC = PaygateWebViewController(htmlContent: htmlContent, bounces: bounces, productIdMap: productIdMap) { [weak self] action, productId in
            var resultMap: [String: Any] = ["action": action]
            if let productId = productId {
                resultMap["productId"] = productId
            }
            self?.pendingResult?(resultMap)
            self?.pendingResult = nil
        }

        switch presentationStyle {
        case "fullScreen":
            paygateVC.modalPresentationStyle = .fullScreen
            paygateVC.modalTransitionStyle = .coverVertical
        default:
            paygateVC.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *),
               let sheet = paygateVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }
        rootVC.present(paygateVC, animated: true)
    }
}

// MARK: - PaygateWebViewController

class PaygateWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let htmlContent: String
    private let bounces: Bool
    private let productIdMap: [String: String]
    private let onComplete: (String, String?) -> Void
    private var webView: WKWebView!
    private var isPurchasing = false

    init(htmlContent: String, bounces: Bool = false, productIdMap: [String: String] = [:], onComplete: @escaping (String, String?) -> Void) {
        self.htmlContent = htmlContent
        self.bounces = bounces
        self.productIdMap = productIdMap
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        loadContent()
    }

    private func loadContent() {
        let viewportMeta = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, viewport-fit=cover\">"
        let html: String
        if htmlContent.range(of: "<head>", options: .caseInsensitive) != nil {
            html = htmlContent.replacingOccurrences(
                of: "<head>", with: "<head>\(viewportMeta)", options: .caseInsensitive
            )
        } else {
            html = "\(viewportMeta)\(htmlContent)"
        }
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "paygate")
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.bounces = bounces
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "paygate",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "close":
            dismiss(animated: true) { [weak self] in
                self?.onComplete("dismissed", nil)
            }
        case "purchase":
            guard let productId = body["productId"] as? String else { return }
            handlePurchase(productId: productId)
        default:
            break
        }
    }

    private func handlePurchase(productId: String) {
        guard !isPurchasing else { return }
        isPurchasing = true

        let storeProductId = productIdMap[productId] ?? productId
        print("[Paygate] Purchase requested: \(productId) → App Store ID: \(storeProductId)")

        Task { @MainActor in
            do {
                let purchasedId = try await StoreKitManager.shared.purchase(storeProductId)
                if let purchasedId = purchasedId {
                    print("[Paygate] Purchase completed: \(purchasedId)")
                    dismiss(animated: true) { [weak self] in
                        self?.onComplete("purchased", purchasedId)
                    }
                } else {
                    print("[Paygate] Purchase cancelled by user")
                    isPurchasing = false
                    webView.evaluateJavaScript(
                        "window.dispatchEvent(new CustomEvent('paygatePurchaseCancelled'))",
                        completionHandler: nil
                    )
                }
            } catch {
                print("[Paygate] Purchase error: \(error.localizedDescription)")
                isPurchasing = false
                webView.evaluateJavaScript(
                    "window.dispatchEvent(new CustomEvent('paygatePurchaseError', {detail: {message: \"\(error.localizedDescription.replacingOccurrences(of: "\"", with: "\\\""))\"}}))",
                    completionHandler: nil
                )
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .other || navigationAction.navigationType == .reload {
            decisionHandler(.allow)
        } else {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}

import Flutter
import UIKit
import WebKit

public class PaygateFlutterPlugin: NSObject, FlutterPlugin {
    private static var apiKey: String?
    private static var baseURL: String = "http://localhost:4000"
    private var pendingResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.paygate.flutter/sdk", binaryMessenger: registrar.messenger())
        let instance = PaygateFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "launch":
            handleLaunch(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
            return
        }

        PaygateFlutterPlugin.apiKey = apiKey
        if let baseURL = args["baseURL"] as? String {
            PaygateFlutterPlugin.baseURL = baseURL
        }
        result(nil)
    }

    private func handleLaunch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let apiKey = PaygateFlutterPlugin.apiKey else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let flowId = args["flowId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "flowId is required", details: nil))
            return
        }

        self.pendingResult = result

        // Fetch the flow data
        fetchFlow(flowId: flowId, apiKey: apiKey, baseURL: PaygateFlutterPlugin.baseURL) { [weak self] fetchResult in
            DispatchQueue.main.async {
                switch fetchResult {
                case .success(let flowData):
                    self?.presentFlow(flowData: flowData, apiKey: apiKey, baseURL: PaygateFlutterPlugin.baseURL)
                case .failure(let error):
                    self?.pendingResult?(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
                    self?.pendingResult = nil
                }
            }
        }
    }

    private func presentFlow(flowData: [String: Any], apiKey: String, baseURL: String) {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController?.topMostViewController() else {
            pendingResult?(FlutterError(code: "NO_VC", message: "No view controller available", details: nil))
            pendingResult = nil
            return
        }

        let htmlContent = flowData["htmlContent"] as? String ?? ""
        let flowId = flowData["id"] as? String ?? ""

        let paygateVC = PaygateWebViewController(
            htmlContent: htmlContent,
            flowId: flowId,
            apiKey: apiKey,
            baseURL: baseURL
        ) { [weak self] action, productId in
            var resultMap: [String: Any] = ["action": action]
            if let productId = productId {
                resultMap["productId"] = productId
            }
            self?.pendingResult?(resultMap)
            self?.pendingResult = nil
        }

        paygateVC.modalPresentationStyle = .fullScreen
        paygateVC.modalTransitionStyle = .coverVertical
        rootVC.present(paygateVC, animated: true)
    }

    private func fetchFlow(
        flowId: String,
        apiKey: String,
        baseURL: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/sdk/flows/\(flowId)") else {
            completion(.failure(NSError(domain: "Paygate", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "Paygate", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "Paygate", code: -3, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }

            completion(.success(json))
        }.resume()
    }
}

// MARK: - PaygateWebViewController

class PaygateWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let htmlContent: String
    private let flowId: String
    private let apiKey: String
    private let baseURL: String
    private let onComplete: (String, String?) -> Void
    private var webView: WKWebView!

    init(
        htmlContent: String,
        flowId: String,
        apiKey: String,
        baseURL: String,
        onComplete: @escaping (String, String?) -> Void
    ) {
        self.htmlContent = htmlContent
        self.flowId = flowId
        self.apiKey = apiKey
        self.baseURL = baseURL
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
        webView.loadHTMLString(htmlContent, baseURL: URL(string: baseURL))
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "paygate")
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
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
            let productId = body["productId"] as? String
            trackEvent(eventType: "purchase_initiated", metadata: productId != nil ? ["productId": productId!] : [:])
            dismiss(animated: true) { [weak self] in
                self?.onComplete("purchased", productId)
            }
        default:
            break
        }
    }

    private func trackEvent(eventType: String, metadata: [String: String]) {
        guard let url = URL(string: "\(baseURL)/api/sdk/flows/\(flowId)/events") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["eventType": eventType, "metadata": metadata]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
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

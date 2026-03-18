import Flutter
import UIKit
import PaygateSDK

public class PaygateFlutterPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.paygate.flutter/sdk", binaryMessenger: registrar.messenger())
        let instance = PaygateFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "launchFlow":
            handleLaunchFlow(call: call, result: result)
        case "launchGate":
            handleLaunchGate(call: call, result: result)
        case "purchase":
            handlePurchase(call: call, result: result)
        case "getActiveSubscriptionProductIDs":
            handleGetActiveSubscriptionProductIDs(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleGetActiveSubscriptionProductIDs(result: @escaping FlutterResult) {
        Task { @MainActor in
            let active = await Array(Paygate.activeSubscriptionProductIDs)
            result(active)
        }
    }

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let apiKey = args?["apiKey"] as? String ?? ""
        let baseURL = args?["baseURL"] as? String
        let gateIds = args?["gateIds"] as? [String]
        let flowIds = args?["flowIds"] as? [String]

        Task { @MainActor in
            await Paygate.initialize(apiKey: apiKey, baseURL: baseURL, gateIds: gateIds, flowIds: flowIds)
            let active = await Array(Paygate.activeSubscriptionProductIDs)
            result(active)
        }
    }

    private func handleLaunchFlow(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let flowId = args["flowId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "flowId is required", details: nil))
            return
        }

        let bounces = args["bounces"] as? Bool ?? false
        let presentationStyle = parsePresentationStyle(args["presentationStyle"] as? String)

        Task { @MainActor in
            do {
                let productId = try await Paygate.launchFlow(
                    flowId,
                    bounces: bounces,
                    presentationStyle: presentationStyle
                )
                result(productId)
            } catch {
                result(FlutterError(code: "LAUNCH_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func handleLaunchGate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let gateId = args["gateId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "gateId is required", details: nil))
            return
        }

        let bounces = args["bounces"] as? Bool ?? false
        let presentationStyle = parsePresentationStyle(args["presentationStyle"] as? String)

        Task { @MainActor in
            do {
                let productId = try await Paygate.launchGate(
                    gateId,
                    bounces: bounces,
                    presentationStyle: presentationStyle
                )
                result(productId)
            } catch {
                result(FlutterError(code: "LAUNCH_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func handlePurchase(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let productId = args["productId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "productId is required", details: nil))
            return
        }

        Task { @MainActor in
            do {
                let purchasedId = try await Paygate.purchase(productId)
                let active = await Array(Paygate.activeSubscriptionProductIDs)
                if let purchasedId = purchasedId {
                    result(["action": "purchased", "productId": purchasedId, "activeSubscriptionProductIDs": active])
                } else {
                    result(["action": "cancelled", "activeSubscriptionProductIDs": active])
                }
            } catch {
                result(FlutterError(code: "PURCHASE_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func parsePresentationStyle(_ value: String?) -> PaygatePresentationStyle {
        switch value {
        case "fullScreen":
            return .fullScreen
        default:
            return .sheet
        }
    }
}

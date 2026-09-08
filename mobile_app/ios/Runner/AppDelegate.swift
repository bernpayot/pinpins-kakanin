import Flutter
import ShopifyCheckoutSheetKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var checkoutResult: FlutterResult?
  private var checkoutController: UIViewController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    FlutterMethodChannel(
      name: "com.pinpinskakanin/checkout",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "present" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.presentCheckout(call: call, result: result)
    }
  }

  private func presentCheckout(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      checkoutResult == nil,
      let arguments = call.arguments as? [String: Any],
      let value = arguments["checkoutUrl"] as? String,
      let url = URL(string: value),
      url.scheme == "https"
    else {
      result(FlutterError(code: "invalid_checkout", message: "Invalid or active checkout", details: nil))
      return
    }

    let presenter = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController

    guard let presenter else {
      result(FlutterError(code: "presentation_failed", message: "Could not open checkout", details: nil))
      return
    }

    checkoutResult = result
    checkoutController = ShopifyCheckoutSheetKit.present(
      checkout: url,
      from: presenter,
      delegate: self
    )
  }

  private func finishCheckout(_ status: String) {
    checkoutResult?(status)
    checkoutResult = nil
  }
}

extension AppDelegate: @preconcurrency CheckoutDelegate {
  func checkoutDidComplete(event _: CheckoutCompletedEvent) {
    finishCheckout("completed")
  }

  func checkoutDidCancel() {
    checkoutController?.dismiss(animated: true)
    checkoutController = nil
    finishCheckout("cancelled")
  }

  func checkoutDidFail(error: ShopifyCheckoutSheetKit.CheckoutError) {
    checkoutController = nil
    checkoutResult?(
      FlutterError(code: "checkout_failed", message: String(describing: error), details: nil)
    )
    checkoutResult = nil
  }

  func shouldRecoverFromError(error _: ShopifyCheckoutSheetKit.CheckoutError) -> Bool {
    false
  }

  func checkoutDidEmitWebPixelEvent(event _: ShopifyCheckoutSheetKit.PixelEvent) {}
}

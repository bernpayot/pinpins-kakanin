package com.example.mobile_app

import android.net.Uri
import com.shopify.checkoutsheetkit.CheckoutException
import com.shopify.checkoutsheetkit.DefaultCheckoutEventProcessor
import com.shopify.checkoutsheetkit.ShopifyCheckoutSheetKit
import com.shopify.checkoutsheetkit.lifecycleevents.CheckoutCompletedEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingCheckoutResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pinpinskakanin/checkout")
            .setMethodCallHandler { call, result ->
                if (call.method != "present") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val checkoutUrl = call.argument<String>("checkoutUrl")
                if (checkoutUrl == null || Uri.parse(checkoutUrl).scheme != "https") {
                    result.error("invalid_url", "Invalid checkout URL", null)
                } else if (pendingCheckoutResult != null) {
                    result.error("checkout_active", "Checkout is already open", null)
                } else {
                    presentCheckout(checkoutUrl, result)
                }
            }
    }

    private fun presentCheckout(checkoutUrl: String, result: MethodChannel.Result) {
        pendingCheckoutResult = result
        val processor = object : DefaultCheckoutEventProcessor(this@MainActivity) {
            override fun onCheckoutCompleted(checkoutCompletedEvent: CheckoutCompletedEvent) {
                finishCheckout("completed")
            }

            override fun onCheckoutCanceled() {
                finishCheckout("cancelled")
            }

            override fun onCheckoutFailed(error: CheckoutException) {
                failCheckout(error.errorCode, error.errorDescription)
            }
        }

        if (ShopifyCheckoutSheetKit.present(checkoutUrl, this, processor) == null) {
            failCheckout("presentation_failed", "Could not open checkout")
        }
    }

    private fun finishCheckout(status: String) {
        pendingCheckoutResult?.success(status)
        pendingCheckoutResult = null
    }

    private fun failCheckout(code: String, message: String) {
        pendingCheckoutResult?.error(code, message, null)
        pendingCheckoutResult = null
    }
}

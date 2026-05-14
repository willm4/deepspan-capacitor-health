package com.deepspan.health

import android.app.Activity
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Activity that displays the app's privacy policy for Health Connect permissions.
 *
 * This activity is launched by Health Connect when the user wants to see why the
 * app needs health data access. It shows a WebView with the privacy policy page.
 *
 * Customize the URL by adding a string resource in your app's res/values/strings.xml:
 *
 * ```xml
 * <resources>
 *     <string name="health_connect_privacy_policy_url">https://yourapp.com/privacy</string>
 * </resources>
 * ```
 *
 * Alternatively, place an HTML file at www/privacypolicy.html in your Capacitor app assets.
 */
class PermissionsRationaleActivity : Activity() {

    private val defaultUrl = "file:///android_asset/public/privacypolicy.html"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(applicationContext)
        webView.webViewClient = WebViewClient()
        webView.settings.javaScriptEnabled = false
        setContentView(webView)

        webView.loadUrl(getPrivacyPolicyUrl())
    }

    private fun getPrivacyPolicyUrl(): String {
        return try {
            val resId = resources.getIdentifier(
                "health_connect_privacy_policy_url",
                "string",
                packageName
            )
            if (resId != 0) getString(resId) else defaultUrl
        } catch (e: Exception) {
            defaultUrl
        }
    }
}

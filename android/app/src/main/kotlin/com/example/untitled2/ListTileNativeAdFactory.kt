
package com.sid.mydocverter.pdfconverter

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

class ListTileNativeAdFactory(
    private val context: Context
) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {

        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        val iconView = adView.findViewById<ImageView>(R.id.ad_icon)
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)

        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        if (nativeAd.body != null) {
            bodyView.text = nativeAd.body
            bodyView.visibility = View.VISIBLE
            adView.bodyView = bodyView
        } else {
            bodyView.visibility = View.GONE
        }

        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            iconView.visibility = View.VISIBLE
            adView.iconView = iconView
        } else {
            iconView.visibility = View.GONE
        }

        if (nativeAd.mediaContent != null) {
            mediaView.setMediaContent(nativeAd.mediaContent!!)
            mediaView.visibility = View.VISIBLE
            adView.mediaView = mediaView
        } else {
            mediaView.visibility = View.GONE
        }

        if (nativeAd.callToAction != null) {
            callToActionView.text = nativeAd.callToAction
            callToActionView.visibility = View.VISIBLE
            adView.callToActionView = callToActionView
        } else {
            callToActionView.visibility = View.GONE
        }

        adView.setNativeAd(nativeAd)

        return adView
    }
}

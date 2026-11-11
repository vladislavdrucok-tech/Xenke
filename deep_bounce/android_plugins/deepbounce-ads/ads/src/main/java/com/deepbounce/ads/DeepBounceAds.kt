package com.deepbounce.ads

import android.app.Activity
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Deep Bounce: Google Mobile Ads (rewarded + interstitial) behind Google UMP consent.
 *
 * Order, as in Google's documentation:
 *  1. requestConsentInfoUpdate() on every start, 2. loadAndShowConsentFormIfRequired(),
 *  3. only if canRequestAds(): MobileAds.initialize() and ad requests.
 * The privacy options entry point (showPrivacyOptionsForm) is exposed for the settings screen.
 * All SDK calls run on the UI thread; signals are emitted on Godot's render thread.
 */
class DeepBounceAds(godot: Godot) : GodotPlugin(godot) {

    private val tag = "DeepBounceAds"
    private var consentInformation: ConsentInformation? = null
    private val mobileAdsStarted = AtomicBoolean(false)
    // one loaded ad per ad unit: revive, double-crystals and interstitial units are separate
    private val rewarded = java.util.concurrent.ConcurrentHashMap<String, RewardedAd>()
    private val interstitial = java.util.concurrent.ConcurrentHashMap<String, InterstitialAd>()
    private var testDeviceIds: List<String> = emptyList()
    private var maxContentRating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        // consent flow finished (also after an error): can ads be requested now, must the privacy entry be shown
        SignalInfo("consent_finished", java.lang.Boolean::class.java, java.lang.Boolean::class.java, String::class.java),
        SignalInfo("privacy_form_closed", String::class.java),
        SignalInfo("ads_initialized"),
        // kind = "rewarded" | "interstitial"
        SignalInfo("ad_loaded", String::class.java, String::class.java),
        SignalInfo("ad_failed_to_load", String::class.java, String::class.java, Integer::class.java, String::class.java),
        // (kind, ad unit, …)
        SignalInfo("ad_showed", String::class.java, String::class.java),
        SignalInfo("ad_failed_to_show", String::class.java, String::class.java, Integer::class.java, String::class.java),
        SignalInfo("ad_dismissed", String::class.java, String::class.java),
        SignalInfo("user_earned_reward", String::class.java, String::class.java, String::class.java, Integer::class.java),
    )

    private fun emit(name: String, vararg args: Any) {
        runOnRenderThread { emitSignal(name, *args) }
    }

    private fun ui(block: (Activity) -> Unit) {
        val act = activity ?: return
        act.runOnUiThread {
            try {
                block(act)
            } catch (e: Throwable) {
                Log.e(tag, "UI call failed", e)
            }
        }
    }

    /**
     * testMode: use Google's debug geography (EEA) and register test devices so the consent form and test ads
     * can be checked; never true in a store build with real ad units.
     * contentRating: "G", "PG", "T" or "MA" (max ad content rating, matched to the game's rating).
     */
    @UsedByGodot
    fun start(testMode: Boolean, debugEea: Boolean, testDevicesCsv: String, contentRating: String) {
        testDeviceIds = testDevicesCsv.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        maxContentRating = when (contentRating) {
            "G" -> RequestConfiguration.MAX_AD_CONTENT_RATING_G
            "T" -> RequestConfiguration.MAX_AD_CONTENT_RATING_T
            "MA" -> RequestConfiguration.MAX_AD_CONTENT_RATING_MA
            else -> RequestConfiguration.MAX_AD_CONTENT_RATING_PG
        }
        ui { act ->
            val info = UserMessagingPlatform.getConsentInformation(act)
            consentInformation = info
            val builder = ConsentRequestParameters.Builder()
            if (testMode) {
                val dbg = ConsentDebugSettings.Builder(act)
                if (debugEea) dbg.setDebugGeography(ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA)
                for (id in testDeviceIds) dbg.addTestDeviceHashedId(id)
                builder.setConsentDebugSettings(dbg.build())
            }
            info.requestConsentInfoUpdate(act, builder.build(), {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(act) { formError ->
                    finishConsent(formError?.message ?: "")
                }
            }, { requestError ->
                // network trouble etc.: ads may still be allowed from an earlier session's consent
                finishConsent(requestError.message)
            })
            // a consent obtained in an earlier session allows starting the SDK right away
            if (info.canRequestAds()) startMobileAds()
        }
    }

    private fun finishConsent(error: String) {
        val info = consentInformation
        val can = info?.canRequestAds() ?: false
        val privacyRequired = info?.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
        if (can) startMobileAds()
        emit("consent_finished", can, privacyRequired, error)
    }

    private fun startMobileAds() {
        if (!mobileAdsStarted.compareAndSet(false, true)) return
        ui { act ->
            val conf = RequestConfiguration.Builder()
                .setMaxAdContentRating(maxContentRating)
                .setTestDeviceIds(testDeviceIds)
                .build()
            MobileAds.setRequestConfiguration(conf)
            Thread {
                MobileAds.initialize(act) { emit("ads_initialized") }
            }.start()
        }
    }

    @UsedByGodot
    fun canRequestAds(): Boolean = consentInformation?.canRequestAds() ?: false

    @UsedByGodot
    fun isPrivacyOptionsRequired(): Boolean =
        consentInformation?.privacyOptionsRequirementStatus == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

    @UsedByGodot
    fun showPrivacyOptionsForm() {
        ui { act ->
            UserMessagingPlatform.showPrivacyOptionsForm(act) { formError ->
                if (consentInformation?.canRequestAds() == true) startMobileAds()
                emit("privacy_form_closed", formError?.message ?: "")
            }
        }
    }

    /** Testing only: forget the stored consent so the form appears again. */
    @UsedByGodot
    fun resetConsent() {
        ui { _ -> consentInformation?.reset() }
    }

    @UsedByGodot
    fun loadRewarded(adUnitId: String) {
        if (!canRequestAds()) {
            emit("ad_failed_to_load", "rewarded", adUnitId, -100, "consent: ads may not be requested")
            return
        }
        ui { act ->
            RewardedAd.load(act, adUnitId, AdRequest.Builder().build(), object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewarded[adUnitId] = ad
                    emit("ad_loaded", "rewarded", adUnitId)
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewarded.remove(adUnitId)
                    emit("ad_failed_to_load", "rewarded", adUnitId, error.code, error.message)
                }
            })
        }
    }

    @UsedByGodot
    fun loadInterstitial(adUnitId: String) {
        if (!canRequestAds()) {
            emit("ad_failed_to_load", "interstitial", adUnitId, -100, "consent: ads may not be requested")
            return
        }
        ui { act ->
            InterstitialAd.load(act, adUnitId, AdRequest.Builder().build(), object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitial[adUnitId] = ad
                    emit("ad_loaded", "interstitial", adUnitId)
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitial.remove(adUnitId)
                    emit("ad_failed_to_load", "interstitial", adUnitId, error.code, error.message)
                }
            })
        }
    }

    @UsedByGodot
    fun isRewardedReady(adUnitId: String): Boolean = rewarded.containsKey(adUnitId)

    @UsedByGodot
    fun isInterstitialReady(adUnitId: String): Boolean = interstitial.containsKey(adUnitId)

    @UsedByGodot
    fun showRewarded(adUnitId: String) {
        val ad = rewarded.remove(adUnitId)   // a rewarded ad is shown once
        if (ad == null) {
            emit("ad_failed_to_show", "rewarded", adUnitId, -1, "not loaded")
            return
        }
        ui { act ->
            ad.fullScreenContentCallback = callback("rewarded", adUnitId)
            ad.show(act) { item -> emit("user_earned_reward", "rewarded", adUnitId, item.type, item.amount) }
        }
    }

    @UsedByGodot
    fun showInterstitial(adUnitId: String) {
        val ad = interstitial.remove(adUnitId)
        if (ad == null) {
            emit("ad_failed_to_show", "interstitial", adUnitId, -1, "not loaded")
            return
        }
        ui { act ->
            ad.fullScreenContentCallback = callback("interstitial", adUnitId)
            ad.show(act)
        }
    }

    /** Ad-Free bought: drop everything that is loaded, nothing is requested any more. */
    @UsedByGodot
    fun disableAds() {
        rewarded.clear()
        interstitial.clear()
    }

    private fun callback(kind: String, unit: String) = object : FullScreenContentCallback() {
        override fun onAdShowedFullScreenContent() = emit("ad_showed", kind, unit)
        override fun onAdFailedToShowFullScreenContent(error: AdError) = emit("ad_failed_to_show", kind, unit, error.code, error.message)
        override fun onAdDismissedFullScreenContent() = emit("ad_dismissed", kind, unit)
    }
}

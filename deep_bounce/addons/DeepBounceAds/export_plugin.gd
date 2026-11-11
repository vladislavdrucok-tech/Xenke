@tool
extends EditorPlugin
## Adds the DeepBounceAds Android library, Google Mobile Ads + UMP dependencies and the AdMob App ID
## (from res://config/monetization.cfg) to Android exports. Source: android_plugins/deepbounce-ads.

var export_plugin: AdsExportPlugin

func _enter_tree() -> void:
	export_plugin = AdsExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AdsExportPlugin extends EditorExportPlugin:
	const NAME := "DeepBounceAds"
	# keep in sync with android_plugins/deepbounce-ads/ads/build.gradle.kts
	const DEPS := ["com.google.android.gms:play-services-ads:24.9.0", "com.google.android.ump:user-messaging-platform:3.2.0"]

	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug) -> PackedStringArray:
		return PackedStringArray([NAME + "/bin/" + NAME + ("-debug.aar" if debug else "-release.aar")])

	func _get_android_dependencies(platform, debug) -> PackedStringArray:
		return PackedStringArray(DEPS)

	func _get_android_manifest_application_element_contents(platform, debug) -> String:
		var cfg := ConfigFile.new()
		cfg.load("res://config/monetization.cfg")
		var app_id := String(cfg.get_value("admob", "test_app_id", ""))
		var real_id := String(cfg.get_value("admob", "real_app_id", ""))
		if not bool(cfg.get_value("admob", "use_test_ads", true)) and real_id != "":
			app_id = real_id
		elif not debug:
			push_warning("DeepBounceAds: release export with Google's TEST AdMob App ID (set real_app_id and use_test_ads=false in config/monetization.cfg)")
		# Without this entry the Google Mobile Ads SDK stops the app at start.
		return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n' % app_id

	func _get_name() -> String:
		return NAME

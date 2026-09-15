import Foundation
import LazyMemoCore

/// 화면의 말은 이 문을 지난다 — `LazyMemoCore/Words.swift` 와 같은 규칙.
/// 한국어 원문이 열쇠이고, 영어는 `Resources/en.lproj/Localizable.strings` 가 안다.
func L(_ key: String.LocalizationValue, locale: Locale = Words.locale) -> String {
    let resource = LocalizedStringResource(key, locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    return String(localized: resource)
}

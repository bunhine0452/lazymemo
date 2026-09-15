import Foundation
import LazyMemoCore

/// 화면의 말은 이 문을 지난다 — `LazyMemoCore/Words.swift` 와 같은 규칙.
/// 한국어 원문이 열쇠이고, 영어는 `Resources/en.lproj/Localizable.strings` 가 안다.
func L(_ key: String.LocalizationValue, locale: Locale = Words.locale) -> String {
    let resource = LocalizedStringResource(key, locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    return String(localized: resource)
}

/// 모델이나 해석기가 낸 문장 — 표에 있으면 번역하고, 없으면 그대로. `%` 가 든 글은 형식 문자열로 오해받지 않게 건드리지 않는다.
func Lsoft(_ text: String) -> String {
    text.contains("%") ? text : L(String.LocalizationValue(text))
}

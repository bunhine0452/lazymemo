import Foundation

/// 화면의 말은 이 문을 지난다 — `LazyMemoCore/Words.swift` 와 같은 규칙.
///
/// 한국어 원문이 열쇠이고, 영어는 `Resources/en.lproj/Localizable.strings` 가 안다.
/// 이 모듈의 표는 패키지 번들에 있으므로 SwiftUI 의 `Text("…")` 가 앱 번들에서
/// 찾는 것과는 다른 자리다 — 글자 하나까지 `Text(L("…"))` 로 지난다.
func L(_ key: String.LocalizationValue, locale: Locale = .current) -> String {
    let resource = LocalizedStringResource(key, locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    return String(localized: resource)
}

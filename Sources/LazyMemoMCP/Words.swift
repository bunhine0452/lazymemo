import Foundation
import LazyMemoCore

/// 도구 설명과 안내문은 이 문을 지난다 — `LazyMemoCore/Words.swift` 와 같은 규칙.
/// Claude Desktop 이 띄운 프로세스라 사용자의 시스템 언어를 그대로 따른다.
func L(_ key: String.LocalizationValue, locale: Locale = Words.locale) -> String {
    let resource = LocalizedStringResource(key, locale: locale, bundle: .atURL(Bundle.module.bundleURL))
    return String(localized: resource)
}

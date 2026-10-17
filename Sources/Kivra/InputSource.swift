struct InputSource: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The primary language the layout types, such as "en" or "ru".
    var languageCode: String?
}

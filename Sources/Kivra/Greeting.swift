import Foundation

/// A short word typed in a layout's language to show switching in action.
enum Greeting {
    static func word(forLanguage languageCode: String?, layoutName: String) -> String {
        guard let languageCode else {
            return layoutName
        }
        let language = Locale(identifier: languageCode).language.languageCode?.identifier ?? languageCode
        if let word = words[language] {
            return word
        }
        // The language's own name still shows the switch, such as "español".
        return Locale(identifier: language).localizedString(forLanguageCode: language) ?? layoutName
    }

    private static let words: [String: String] = [
        "ar": "مرحبا",
        "be": "Прывітанне",
        "bg": "Здравей",
        "cs": "Ahoj",
        "da": "Hej",
        "de": "Hallo",
        "el": "Γειά",
        "en": "Hello",
        "es": "Hola",
        "et": "Tere",
        "fa": "سلام",
        "fi": "Hei",
        "fr": "Bonjour",
        "he": "שלום",
        "hi": "नमस्ते",
        "hr": "Bok",
        "hu": "Szia",
        "hy": "Բարեւ",
        "it": "Ciao",
        "ja": "こんにちは",
        "ka": "გამარჯობა",
        "kk": "Сәлем",
        "ko": "안녕하세요",
        "lt": "Labas",
        "lv": "Sveiki",
        "nb": "Hei",
        "nl": "Hallo",
        "pl": "Cześć",
        "pt": "Olá",
        "ro": "Salut",
        "ru": "Привет",
        "sk": "Ahoj",
        "sr": "Здраво",
        "sv": "Hej",
        "th": "สวัสดี",
        "tr": "Merhaba",
        "uk": "Привіт",
        "vi": "Xin chào",
        "zh": "你好",
    ]
}

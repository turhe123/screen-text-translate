# ScreenTextTranslate — specification

**Tagline:** Drag a box over foreign text anywhere on screen and see the translation right there in a floating card.

**Category:** Screen & OCR

**Inspired by (paid):** OCR Quick Translate ($29.99 one-time)

**Frameworks:** SwiftUI, AppKit, Vision, ScreenCaptureKit, Translation, NaturalLanguage, CoreGraphics

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: OCR Quick Translate on the App Store captures a screen region with a custom hotkey, recognizes the text and translates it, sold as a lifetime unlock at 29.99 or a 0.99 monthly plan. Apps such as Screen Translate (30 per year) and the free open-source ScreenTranslate show how many people read untranslatable text in videos, games, images, PDFs and apps. Since macOS ships on-device Translation, a free rebuild needs no servers or paid API.

Feature set for ScreenTextTranslate: press a hotkey, drag a rectangle, and the app recognizes the text, detects its language, translates to a target language and shows the result in a small floating card next to the selection with Copy Original, Copy Translation, and Close buttons. A second mode overlays the translated text directly on top of the original region as a snapshot. A history of the last 20 translations lives in the menu for quick copy. Settings choose the target language and a list of favorite source languages to speed recognition.

UI spec: MenuBarExtra with Translate Region, Recent translations list, Settings, Quit. A full-screen overlay window handles region selection with a crosshair. The result card is an NSPanel that dismisses on Escape or click outside, with a text area, detected language badge, and a target language popup. Settings window fields: hotkey recorder, target language picker, overlay mode toggle, auto-copy translation toggle, history length, launch at login. Empty state in the menu: Nothing translated yet. If the language pack is missing, the card shows a Download Language button.

Technical approach: capture the region with ScreenCaptureKit SCScreenshotManager captureImage using a sourceRect, requiring Screen Recording permission requested with CGRequestScreenCaptureAccess. Recognize text with Vision VNRecognizeTextRequest at accurate level with automatic language detection enabled on supported versions, and gather observations with bounding boxes for the overlay mode. Detect language with NaturalLanguage NLLanguageRecognizer. Translate using the Translation framework: on macOS 15 and later use TranslationSession inside a SwiftUI view with the translationTask modifier, which also handles language downloads with system UI. On macOS 14, where that API is unavailable, the card shows the recognized text and offers Look Up through the system dictionary service instead, with a clear notice that translation needs a newer macOS. Hotkey via Carbon RegisterEventHotKey. Persist settings with AppStorage and history in a small JSON file in Application Support.

Edge cases and error handling: if no text is found, show a No text detected card that fades after two seconds. If source and target languages match, skip translation and just show the text. Handle vertical text by trying the Vision orientation option. Split multi-line paragraphs into one block, joined with spaces unless a line ends with punctuation. Limit region size to avoid huge images and downscale if needed. If permission is denied, show a guide to the Screen Recording pane. Escape cancels selection at any time, and the overlay must work across multiple displays.

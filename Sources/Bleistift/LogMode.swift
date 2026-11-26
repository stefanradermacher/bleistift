// Copyright 2026 Stefan Radermacher
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AppKit
import SwiftUI

/// A pattern of file names, such as *.log, whose files are shown as logs: they open at their
/// end and follow new lines written by other programs.
struct LogPattern: Codable, Equatable, Identifiable {
    /// Only for the list in the settings; not stored.
    var id = UUID()
    var pattern: String
    var readOnly: Bool

    private enum CodingKeys: String, CodingKey { case pattern, readOnly }

    /// Shell-style matching against the file name, ignoring case: * any characters, ? one.
    func matches(_ name: String) -> Bool {
        let pattern = pattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return false }
        return fnmatch(pattern, name, FNM_CASEFOLD) == 0
    }
}

enum LogMode {
    static let defaultPatterns = [LogPattern(pattern: "*.log", readOnly: true)]

    static var defaultValue: Data { (try? JSONEncoder().encode(defaultPatterns)) ?? Data() }

    static var patterns: [LogPattern] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Preferences.logPatterns),
                  let patterns = try? JSONDecoder().decode([LogPattern].self, from: data)
            else { return defaultPatterns }
            return patterns
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Preferences.logPatterns)
        }
    }

    /// The first pattern the file's name matches.
    static func pattern(for fileURL: URL) -> LogPattern? {
        patterns.first { $0.matches(fileURL.lastPathComponent) }
    }
}

extension TextDocument {
    static let logModeDidChange = Notification.Name("TextDocumentLogModeDidChange")

    /// What the patterns in the settings say about this file, before any choice made for it.
    private var patternDefaults: (log: Bool, readOnly: Bool) {
        guard let fileURL, let pattern = LogMode.pattern(for: fileURL) else { return (false, false) }
        return (true, pattern.readOnly)
    }

    /// Takes the log mode and read-only state from the choice made for this file, or else from
    /// the patterns in the settings.
    func updateLogMode() {
        let defaults = patternDefaults
        var log = false
        var readOnly = false
        if let fileURL {
            log = FileStateStore.shared.logMode(for: fileURL) ?? defaults.log
            readOnly = FileStateStore.shared.readOnly(for: fileURL) ?? defaults.readOnly
        }
        guard log != isLogFile || readOnly != isReadOnly else { return }
        isLogFile = log
        isReadOnly = readOnly
        NotificationCenter.default.post(name: Self.logModeDidChange, object: self)
    }

    /// Darstellung → Als Log-Datei anzeigen. Remembered for the file; a choice that agrees with
    /// the patterns is forgotten again, so a later change of the patterns applies.
    @objc func toggleLogMode(_ sender: Any?) {
        guard let fileURL else { return }
        let log = !isLogFile
        FileStateStore.shared.recordLogMode(log == patternDefaults.log ? nil : log, for: fileURL)
        updateLogMode()
        if log { editor?.followEnd() }
    }

    /// Darstellung → Nur lesen.
    @objc func toggleReadOnly(_ sender: Any?) {
        guard let fileURL else { return }
        let readOnly = !isReadOnly
        FileStateStore.shared.recordReadOnly(readOnly == patternDefaults.readOnly ? nil : readOnly, for: fileURL)
        updateLogMode()
    }
}

extension EditorViewController {
    /// Read-only documents take no typing; every change goes through shouldChangeText, which
    /// refuses it in a text view that is not editable.
    func applyLogMode() {
        panes.forEach { $0.textView.isEditable = !document.isReadOnly }
        statusBar.updateFormat()
    }

    /// Every pane to the end of the text, with the insertion point there.
    func followEnd() {
        panes.forEach { $0.scrollToEnd(movingInsertionPoint: true) }
    }
}

extension EditorPane {
    /// The last line is in view, give or take a little, or the whole text fits.
    var isScrolledToEnd: Bool {
        let clip = scrollView.contentView
        return clip.bounds.maxY >= textView.frame.height - 48
    }

    /// Shows the end of the text at the bottom. TextKit estimates the height of what it has not
    /// laid out, so the end is approached and then settled in a few steps.
    func scrollToEnd(movingInsertionPoint: Bool) {
        let length = document.textStorage.length
        if movingInsertionPoint { textView.setSelectedRange(NSRange(location: length, length: 0)) }
        textView.approach(length)
        let clip = scrollView.contentView
        for _ in 0..<4 {
            textView.scrollRangeToVisible(NSRange(location: length, length: 0))
            layoutManager.textViewportLayoutController.layoutViewport()
            textView.layoutSubtreeIfNeeded()
            let bottom = max(textView.frame.height - clip.bounds.height, 0)
            if abs(clip.bounds.minY - bottom) < 1 { break }
            clip.scroll(to: NSPoint(x: clip.bounds.minX, y: bottom))
            scrollView.reflectScrolledClipView(clip)
        }
    }
}

/// Explains the log mode when a log file opens, until "Nicht mehr anzeigen" is checked; at
/// most once per launch, so that a session with several logs brings one notice, not several.
@MainActor
enum LogModeNotice {
    static let suppressedKey = "logModeNoticeSuppressed"
    private static var shownThisLaunch = false

    static func showIfDue(for document: TextDocument, in window: NSWindow) {
        guard !shownThisLaunch, !UserDefaults.standard.bool(forKey: suppressedKey), window.attachedSheet == nil else { return }
        shownThisLaunch = true
        let alert = NSAlert()
        alert.messageText = String(localized: "„\(document.displayName ?? "")“ wird als Log-Datei angezeigt")
        var lines = [String(localized: "Bleistift zeigt das Ende der Datei. Schreibt ein Programm neue Zeilen hinein, rückt die Ansicht mit, solange das Ende zu sehen ist; scrollst du nach oben, bleibt sie stehen.")]
        if document.isReadOnly {
            lines.append(String(localized: "Die Datei ist nur zum Lesen geöffnet, damit sie nicht versehentlich geändert wird."))
        }
        lines.append(String(localized: "Umschalten lässt sich das unter Darstellung → Als Log-Datei anzeigen und Nur lesen. Welche Dateien als Log-Dateien gelten, legen die Muster unter Einstellungen → Dateien fest."))
        alert.informativeText = lines.joined(separator: "\n\n")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(localized: "Nicht mehr anzeigen")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.beginSheetModal(for: window) { _ in
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: suppressedKey)
            }
        }
    }
}

/// The list of patterns in Settings → Files.
struct LogPatternSettings: View {
    @State private var patterns = LogMode.patterns

    var body: some View {
        ForEach($patterns) { $entry in
            HStack {
                TextField("Muster", text: $entry.pattern, prompt: Text(verbatim: "*.log"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                Toggle("nur lesen", isOn: $entry.readOnly)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                Button {
                    patterns.removeAll { $0.id == entry.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Muster entfernen")
            }
        }
        HStack {
            Button("Muster hinzufügen") {
                patterns.append(LogPattern(pattern: "", readOnly: true))
            }
            Spacer()
            Button("Standard") {
                patterns = LogMode.defaultPatterns
            }
            .disabled(patterns.map(\.pattern) == LogMode.defaultPatterns.map(\.pattern)
                      && patterns.map(\.readOnly) == LogMode.defaultPatterns.map(\.readOnly))
        }
        .onChange(of: patterns) { _, patterns in
            LogMode.patterns = patterns
        }
    }
}

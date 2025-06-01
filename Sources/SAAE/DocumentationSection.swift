import Foundation

/// Internal enumeration for tracking the current parsing section.
internal enum DocumentationSection {
/// Currently parsing the main description text.
    case description

/// Currently parsing parameter documentation.
    case parameters

/// Currently parsing return value documentation.
    case returns

/// Currently parsing throws documentation.
    case throwsSection
}

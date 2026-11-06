import SwiftUI

extension ToolbarContent {
    /// Keep accepted independent toolbar actions on iOS 26; earlier navigation
    /// bars already provide native ungrouped actions without a glass background.
    @ToolbarContentBuilder func sgIndependentToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) { self.sharedBackgroundVisibility(.hidden) }
        else { self }
    }
}

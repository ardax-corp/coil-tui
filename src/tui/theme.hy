// Named styles the widgets draw with.
use cli::style::{Style, plain, fg, cyan, red, bright_black};

/// The styles widgets use unless they are given their own.
class Theme {
    /// Ordinary text.
    pub text: Style,
    /// Secondary text: hints, separators, empty-list notes.
    pub muted: Style,
    /// Highlights such as key names in hints and gauge fill.
    pub accent: Style,
    /// Titles of blocks, dialogs and tabs.
    pub title: Style,
    /// Borders of unfocused blocks.
    pub border: Style,
    /// Borders of blocks holding the focus.
    pub border_focused: Style,
    /// The selected row of a focused list or table.
    pub selection: Style,
    /// The selected row when the list is not focused.
    pub selection_unfocused: Style,
    /// A button.
    pub button: Style,
    /// The focused button.
    pub button_focused: Style,
    /// A text field.
    pub input: Style,
    /// The focused text field.
    pub input_focused: Style,
    /// Placeholder text in an empty field.
    pub placeholder: Style,
    /// Controls that cannot be used.
    pub disabled: Style,
    /// Error messages.
    pub error: Style,
}

/// Basic colours plus bold, dim, underline and reverse, so it reads on
/// any terminal and in monochrome. Change fields of the result, or pass
/// your own to `App.set_theme`.
fn default_theme() -> Theme {
    return new Theme(
        text: plain(),
        muted: plain().dim(),
        accent: fg(cyan()),
        title: plain().bold(),
        border: plain(),
        border_focused: fg(cyan()).bold(),
        selection: plain().reverse(),
        selection_unfocused: fg(bright_black()).reverse(),
        button: plain(),
        button_focused: plain().reverse().bold(),
        input: plain().underline(),
        input_focused: plain().underline().bold(),
        placeholder: plain().dim(),
        disabled: plain().dim(),
        error: fg(red()),
    );
}

// Named styles the widgets draw with.
use cli::style::{Style, plain, fg, cyan, red, bright_black};

/// The styles widgets use unless they are given their own.
class Theme {
    pub text: Style,
    pub muted: Style,
    pub accent: Style,
    pub title: Style,
    pub border: Style,
    pub border_focused: Style,
    pub selection: Style,
    pub selection_unfocused: Style,
    pub button: Style,
    pub button_focused: Style,
    pub input: Style,
    pub input_focused: Style,
    pub placeholder: Style,
    pub disabled: Style,
    pub error: Style,
}

/// Basic colours plus bold, dim, underline and reverse, so it reads on
/// any terminal and in monochrome.
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

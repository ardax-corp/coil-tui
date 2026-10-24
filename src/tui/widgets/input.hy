// Buttons, checkboxes, radio groups and one-line text inputs.
use cli::keys::Event;
use cli::keys::KeyEvent;
use cli::keys::MouseEvent;
use cli::keys::MouseKind;
use cli::keys::MouseButton;
use cli::keys::describe_key;
use cli::line::Editor;
use cli::line::Edit;
use cli::line::Outcome;
use cli::line::History;
use cli::line::editor;
use cli::line::history;
use cli::line::edit_for;
use cli::style::Style;
use cli::width::width;
use tui::canvas::Canvas;
use tui::geom::Size;
use tui::geom::Align;
use tui::geom::size;
use tui::geom::imax;
use tui::geom::imin;
use tui::layout::Constraint;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;

/// The key spec of a key event, or "" for anything else.
fn key_spec(Event e) -> string {
    return match e {
        Event::Key(k) => describe_key(k),
        default => "",
    };
}

/// Whether `e` is a left-button press.
fn left_press(Event e) -> bool {
    return match e {
        Event::Mouse(m) => match m.kind {
            MouseKind::Press => match m.button {
                MouseButton::Left => true,
                default => false,
            },
            default => false,
        },
        default => false,
    };
}

fn activates(Event e) -> bool {
    let k = key_spec(e);
    return k == "enter" || k == "space" || left_press(e);
}

fn nothing(Ctx ctx) {}

/// A push button: Enter, Space or a click calls `on_press`.
class Button {
    pub label: string,
    pub on_press: fn(Ctx) -> (),
}

impl Button {
    pub static fn new(string label, fn(Ctx) -> () on_press) -> Button {
        return new Button(label, on_press);
    }
}

impl Component for Button {
    fn render(Button b, Canvas cv, Ctx ctx) {
        let st = ctx.theme.button;
        if ctx.has_focus() {
            st = ctx.theme.button_focused;
        }
        cv.put_in(0, 0, cv.w(), "[ " + b.label + " ]", st, Align::Start);
    }

    fn measure(Button b, Size max) -> Size {
        return size(imin(max.w, width(b.label) + 4), imin(max.h, 1));
    }

    fn focusable(Button b) -> bool {
        return true;
    }

    fn handle(Button b, Event e, Ctx ctx) -> bool {
        if activates(e) {
            let f = b.on_press;
            f(ctx);
            return true;
        }
        return false;
    }

    fn constraint(Button b) -> Constraint {
        return Constraint::Auto;
    }
}

fn button(string label, fn(Ctx) -> () on_press) -> Node {
    return mount(Button::new(label, on_press));
}

/// `[x] label`; Enter, Space or a click toggles it.
class Checkbox {
    pub label: string,
    pub checked: bool,
    pub on_change: fn(bool, Ctx) -> (),
}

impl Checkbox {
    pub static fn new(string label, bool checked) -> Checkbox {
        return new Checkbox(label, checked, fn (bool b, Ctx ctx) {});
    }

    pub fn on_change(fn(bool, Ctx) -> () f) -> Checkbox {
        self.on_change = f;
        return self;
    }
}

impl Component for Checkbox {
    fn render(Checkbox c, Canvas cv, Ctx ctx) {
        let mark = "[ ] ";
        if c.checked {
            mark = "[x] ";
        }
        let st = ctx.theme.text;
        if ctx.has_focus() {
            st = ctx.theme.accent;
        }
        let x = cv.put(0, 0, mark, st);
        cv.put(x, 0, c.label, ctx.theme.text);
        if ctx.has_focus() {
            cv.cursor(1, 0);
        }
    }

    fn measure(Checkbox c, Size max) -> Size {
        return size(imin(max.w, width(c.label) + 4), imin(max.h, 1));
    }

    fn focusable(Checkbox c) -> bool {
        return true;
    }

    fn handle(Checkbox c, Event e, Ctx ctx) -> bool {
        if activates(e) {
            c.checked = !c.checked;
            let f = c.on_change;
            f(c.checked, ctx);
            return true;
        }
        return false;
    }

    fn constraint(Checkbox c) -> Constraint {
        return Constraint::Auto;
    }
}

fn checkbox(string label, bool checked, fn(bool, Ctx) -> () on_change) -> Node {
    return mount(Checkbox::new(label, checked).on_change(on_change));
}

/// One choice out of several, listed top to bottom. Up/Down (or a
/// click) select.
class RadioGroup {
    pub options: Vec<string>,
    pub selected: int,
    pub on_change: fn(int, Ctx) -> (),
}

impl RadioGroup {
    pub static fn new(Vec<string> options, int selected) -> RadioGroup {
        return new RadioGroup(options, selected, fn (int i, Ctx ctx) {});
    }

    pub fn on_change(fn(int, Ctx) -> () f) -> RadioGroup {
        self.on_change = f;
        return self;
    }

    pub fn value() -> string {
        if self.selected >= 0 && self.selected < self.options.len() {
            return self.options[self.selected];
        }
        return "";
    }

    pub fn select(int i, Ctx ctx) -> bool {
        if i < 0 || i >= self.options.len() || i == self.selected {
            return false;
        }
        self.selected = i;
        let f = self.on_change;
        f(i, ctx);
        return true;
    }
}

impl Component for RadioGroup {
    fn render(RadioGroup r, Canvas cv, Ctx ctx) {
        let i = 0;
        while i < r.options.len() {
            let mark = "( ) ";
            let st = ctx.theme.text;
            if i == r.selected {
                mark = "(•) ";
                if ctx.has_focus() {
                    st = ctx.theme.accent;
                }
            }
            let x = cv.put(0, i, mark, st);
            cv.put(x, i, r.options[i], ctx.theme.text);
            i++;
        }
        if ctx.has_focus() && r.selected >= 0 {
            cv.cursor(1, r.selected);
        }
    }

    fn measure(RadioGroup r, Size max) -> Size {
        let w = 0;
        for o in r.options {
            w = imax(w, width(o) + 4);
        }
        return size(imin(max.w, w), imin(max.h, r.options.len()));
    }

    fn focusable(RadioGroup r) -> bool {
        return r.options.len() > 0;
    }

    fn handle(RadioGroup r, Event e, Ctx ctx) -> bool {
        let k = key_spec(e);
        if k == "up" {
            return r.select(r.selected - 1, ctx);
        }
        if k == "down" {
            return r.select(r.selected + 1, ctx);
        }
        if k == "home" {
            return r.select(0, ctx);
        }
        if k == "end" {
            return r.select(r.options.len() - 1, ctx);
        }
        return match e {
            Event::Mouse(m) => {
                if left_press(e) {
                    let (x, y) = ctx.local(m);
                    r.select(y, ctx);
                }
                return true;
            },
            default => false,
        };
    }

    fn constraint(RadioGroup r) -> Constraint {
        return Constraint::Auto;
    }
}

fn radio_group(Vec<string> options, int selected, fn(int, Ctx) -> () on_change) -> Node {
    return mount(RadioGroup::new(options, selected).on_change(on_change));
}

/// A one-line text field with readline-style editing (`cli::line`).
/// Tab, Esc and Ctrl-C are left to the app; Up/Down browse the history
/// only when it has entries.
class TextInput {
    pub editor: Editor,
    pub placeholder: string,
    /// Shown instead of each character when not "" (passwords).
    pub mask: string,
    /// Preferred width in a row.
    pub width: int,
    /// Empty the field after Enter (and add the line to the history).
    pub clear_on_submit: bool,
    pub on_change: fn(string, Ctx) -> (),
    pub on_submit: fn(string, Ctx) -> (),
}

impl TextInput {
    pub static fn new(string placeholder) -> TextInput {
        return new TextInput(
            editor(history(100)),
            placeholder,
            "",
            20,
            false,
            fn (string s, Ctx ctx) {},
            fn (string s, Ctx ctx) {},
        );
    }

    pub fn value() -> string {
        return self.editor.text();
    }

    pub fn set_value(string s) {
        self.editor.set_text(s);
    }

    pub fn masked(string m) -> TextInput {
        self.mask = m;
        return self;
    }

    pub fn on_change(fn(string, Ctx) -> () f) -> TextInput {
        self.on_change = f;
        return self;
    }

    pub fn on_submit(fn(string, Ctx) -> () f) -> TextInput {
        self.on_submit = f;
        return self;
    }

    pub fn clearing() -> TextInput {
        self.clear_on_submit = true;
        return self;
    }
}

impl Component for TextInput {
    fn render(TextInput t, Canvas cv, Ctx ctx) {
        let focused = ctx.has_focus();
        let st = ctx.theme.input;
        if focused {
            st = ctx.theme.input_focused;
        }
        cv.fill(0, 0, cv.w(), 1, " ", st);
        if t.editor.len() == 0 && t.placeholder != "" {
            cv.put_in(0, 0, cv.w(), t.placeholder, ctx.theme.placeholder.merge(st), Align::Start);
            if focused {
                cv.cursor(0, 0);
            }
            return;
        }
        let (shown, col) = t.editor.view(cv.w(), t.mask);
        cv.put(0, 0, shown, st);
        if focused {
            cv.cursor(col, 0);
        }
    }

    fn measure(TextInput t, Size max) -> Size {
        return size(imin(max.w, t.width), imin(max.h, 1));
    }

    fn focusable(TextInput t) -> bool {
        return true;
    }

    fn handle(TextInput t, Event e, Ctx ctx) -> bool {
        let k = key_spec(e);
        if k == "tab" || k == "esc" || k == "ctrl+c" {
            return false;
        }
        if (k == "up" || k == "down") && t.editor.history.len() == 0 {
            return false;
        }
        if left_press(e) {
            return true;
        }
        let edit = edit_for(e);
        return match edit {
            Option::Some(ed) => {
                let before = t.editor.text();
                let out = t.editor.apply(ed);
                if out == Outcome::Submit {
                    let line = t.editor.text();
                    if t.clear_on_submit {
                        t.editor.take();
                    }
                    let f = t.on_submit;
                    f(line, ctx);
                    return true;
                }
                if out != Outcome::Continue {
                    return false;
                }
                let after = t.editor.text();
                if after != before {
                    let g = t.on_change;
                    g(after, ctx);
                }
                return true;
            },
            Option::None => false,
        };
    }

    fn constraint(TextInput t) -> Constraint {
        return Constraint::Auto;
    }
}

fn text_input(string placeholder) -> TextInput {
    return TextInput::new(placeholder);
}

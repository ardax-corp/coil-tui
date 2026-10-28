// Driving an `App` without a terminal: send keys, text, clicks and time,
// then read the screen back as text.
use text::Searchable;
use cli::keys::Event;
use cli::keys::Key;
use cli::keys::KeyEvent;
use cli::keys::MouseEvent;
use cli::keys::MouseKind;
use cli::keys::MouseButton;
use cli::keys::key;
use cli::keys::cp_string;
use cli::keys::SHIFT;
use cli::keys::ALT;
use cli::keys::CTRL;
use cli::keys::META;
use cli::screen::Cell;
use cli::color::ColorLevel;
use cli::width::code_points;
use tui::app::App;
use tui::app::app;
use tui::node::Node;
use string::slice_bytes;
use conv::parse_int;

fn named_key(string name) -> Option<Key> {
    if name == "enter" {
        return Option::Some(Key::Enter);
    }
    if name == "tab" {
        return Option::Some(Key::Tab);
    }
    if name == "backtab" {
        return Option::Some(Key::BackTab);
    }
    if name == "backspace" {
        return Option::Some(Key::Backspace);
    }
    if name == "esc" {
        return Option::Some(Key::Esc);
    }
    if name == "up" {
        return Option::Some(Key::Up);
    }
    if name == "down" {
        return Option::Some(Key::Down);
    }
    if name == "left" {
        return Option::Some(Key::Left);
    }
    if name == "right" {
        return Option::Some(Key::Right);
    }
    if name == "home" {
        return Option::Some(Key::Home);
    }
    if name == "end" {
        return Option::Some(Key::End);
    }
    if name == "pageup" {
        return Option::Some(Key::PageUp);
    }
    if name == "pagedown" {
        return Option::Some(Key::PageDown);
    }
    if name == "insert" {
        return Option::Some(Key::Insert);
    }
    if name == "delete" {
        return Option::Some(Key::Delete);
    }
    if name == "space" {
        return Option::Some(Key::Char(32));
    }
    let cps = code_points(name);
    if cps.len() == 1 {
        return Option::Some(Key::Char(cps[0]));
    }
    if name.len() >= 2 && name.starts_with("f") {
        let digits = match slice_bytes(name, 1, name.len()) {
            Result::Ok(t) => t,
            Result::Err(_) => "",
        };
        return match parse_int(digits) {
            Result::Ok(n) => Option::Some(Key::F(n)),
            Result::Err(_) => Option::None,
        };
    }
    return Option::None;
}

/// The key event for a spec as `cli::keys::describe_key` writes it:
/// `"ctrl+c"`, `"shift+tab"`, `"f5"`, `"space"`, `"a"`. Panics on a
/// name it does not know, so a typo fails the test.
fn parse_key(string spec) -> Event {
    let parts: Vec<string> = spec.split("+");
    let mods = 0;
    let i = 0;
    while i < parts.len() - 1 {
        let m = parts[i];
        if m == "ctrl" {
            mods = mods | CTRL;
        } else if m == "alt" {
            mods = mods | ALT;
        } else if m == "shift" {
            mods = mods | SHIFT;
        } else if m == "meta" {
            mods = mods | META;
        } else {
            panic ("unknown modifier in key spec: " + spec);
        }
        i++;
    }
    let name = parts[parts.len() - 1];
    if name == "" && spec.ends_with("+") {
        name = "+";
    }
    return match named_key(name) {
        Option::Some(k) => key(k, mods),
        Option::None => panic ("unknown key in key spec: " + spec),
    };
}

/// A headless app of a fixed size, drawn after every input.
shared class Harness {
    pub app: App,
    /// The test clock in ms.
    pub now: int,
    /// Escapes from the last draw.
    pub out: string,
}

fn harness(Node root, int cols, int rows) -> Harness {
    let a = app(root, ColorLevel::None);
    a.resize(cols, rows);
    let h = new Harness(a, 0, "");
    h.draw();
    return h;
}

impl Harness {
    pub fn draw() -> string {
        self.out = self.app.draw();
        return self.out;
    }

    /// Dispatch `e` and redraw. Returns whether it was handled.
    pub fn send(Event e) -> bool {
        let handled = self.app.dispatch(e);
        self.draw();
        return handled;
    }

    pub fn key(string spec) -> bool {
        return self.send(parse_key(spec));
    }

    /// Several key specs separated by spaces.
    pub fn keys(string specs) {
        let parts: Vec<string> = specs.split(" ");
        for p in parts {
            if p != "" {
                self.key(p);
            }
        }
    }

    /// Type `s`, one key event per character.
    pub fn type_text(string s) {
        for cp in code_points(s) {
            if cp == 10 {
                self.send(key(Key::Enter, 0));
            } else {
                self.send(key(Key::Char(cp), 0));
            }
        }
    }

    pub fn paste(string s) -> bool {
        return self.send(Event::Paste(s));
    }

    /// A mouse event at 0-based cell (`x`, `y`).
    pub fn mouse(MouseKind kind, MouseButton b, int x, int y) -> bool {
        return self.send(Event::Mouse(new MouseEvent(kind, b, x + 1, y + 1, 0)));
    }

    /// Left press and release at 0-based cell (`x`, `y`).
    pub fn click(int x, int y) {
        self.mouse(MouseKind::Press, MouseButton::Left, x, y);
        self.mouse(MouseKind::Release, MouseButton::Left, x, y);
    }

    pub fn wheel(int x, int y, bool up) -> bool {
        if up {
            return self.mouse(MouseKind::Press, MouseButton::WheelUp, x, y);
        }
        return self.mouse(MouseKind::Press, MouseButton::WheelDown, x, y);
    }

    /// Move the clock on by `ms`, run due timers, redraw.
    pub fn advance(int ms) {
        self.now = self.now + ms;
        self.app.tick(self.now);
        self.draw();
    }

    pub fn resize(int cols, int rows) {
        self.send(Event::Resize(cols, rows));
    }

    /// The screen as text, rows joined by "\n".
    pub fn text() -> string {
        return self.app.last.text();
    }

    pub fn row(int y) -> string {
        return self.app.last.row_text(y);
    }

    pub fn cell(int x, int y) -> Cell {
        return self.app.last.get(x, y);
    }

    pub fn focused_id() -> string {
        return self.app.focused_id();
    }
}

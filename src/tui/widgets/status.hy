// Gauges, spinners and key hints.
use string::format;
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

/// Eighths of a cell, for smooth bar ends.
fn partial(int eighths) -> string {
    return match eighths {
        1 => "▏",
        2 => "▎",
        3 => "▍",
        4 => "▌",
        5 => "▋",
        6 => "▊",
        7 => "▉",
        default => "",
    };
}

/// A horizontal bar showing `value` out of `max`, with a label after it
/// ("" for the percentage).
shared class Gauge {
    pub value: int,
    pub max: int,
    pub label: string,
    pub style: Option<Style>,
}

impl Gauge {
    pub static fn new(int value, int max) -> Gauge {
        return new Gauge(value, max, "", Option::None);
    }

    pub fn set(int value) {
        self.value = value;
    }

    /// Percent done, 0 to 100.
    pub fn percent() -> int {
        if self.max <= 0 {
            return 0;
        }
        let v = imax(0, imin(self.value, self.max));
        return v * 100 / self.max;
    }
}

impl Component for Gauge {
    fn render(Gauge g, Canvas cv, Ctx ctx) {
        let label = g.label;
        if label == "" {
            label = format("%i%%", g.percent());
        }
        let lw = width(label) + 1;
        let bar = imax(cv.w() - lw, 0);
        let st = g.style ?? ctx.theme.accent;
        let v = 0;
        if g.max > 0 {
            v = imax(0, imin(g.value, g.max));
        }
        let eighths = 0;
        if g.max > 0 {
            eighths = bar * 8 * v / g.max;
        }
        let full = eighths / 8;
        cv.hline(0, 0, full, "█", st);
        if full < bar {
            cv.put(full, 0, partial(eighths % 8), st);
        }
        cv.hline(full + 1, 0, bar - full - 1, " ", st);
        cv.put(bar + 1, 0, label, ctx.theme.text);
    }

    fn measure(Gauge g, Size max) -> Size {
        return size(max.w, imin(1, max.h));
    }

    fn constraint(Gauge g) -> Constraint {
        return Constraint::Fixed(1);
    }
}

fn gauge(int value, int max) -> Gauge {
    return Gauge::new(value, max);
}

/// An animated spinner and a label. Starts ticking the first time it
/// is drawn; stops when `done` is set.
shared class Spinner {
    pub label: string,
    pub frames: Vec<string>,
    pub frame: int,
    /// Milliseconds per frame.
    pub interval: int,
    pub done: bool,
    pub timer: int,
}

impl Spinner {
    pub static fn new(string label) -> Spinner {
        let frames: Vec<string> = [
            "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
        ];
        return new Spinner(label, frames, 0, 80, false, 0);
    }

    pub fn stop(Ctx ctx) {
        self.done = true;
        ctx.redraw();
        if self.timer != 0 {
            ctx.cancel(self.timer);
            self.timer = 0;
        }
    }

    pub fn start(Ctx ctx) {
        if self.timer != 0 || self.done {
            return;
        }
        let me = self;
        self.timer = ctx.every(
            self.interval,
            fn (Ctx c) use (me) {
                me.frame = (me.frame + 1) % me.frames.len();
            },
        );
    }
}

impl Component for Spinner {
    fn render(Spinner s, Canvas cv, Ctx ctx) {
        s.start(ctx);
        let x = 0;
        if !s.done {
            x = cv.put(0, 0, s.frames[s.frame] + " ", ctx.theme.accent);
        }
        cv.put(x, 0, s.label, ctx.theme.text);
    }

    fn measure(Spinner s, Size max) -> Size {
        return size(imin(max.w, width(s.label) + 2), imin(1, max.h));
    }

    fn constraint(Spinner s) -> Constraint {
        return Constraint::Auto;
    }
}

fn spinner(string label) -> Spinner {
    return Spinner::new(label);
}

/// A line of key hints: `^S save  q quit`.
shared class KeyHints {
    pub keys: Vec<string>,
    pub descriptions: Vec<string>,
}

impl KeyHints {
    pub fn add(string key, string description) -> KeyHints {
        self.keys.push(key);
        self.descriptions.push(description);
        return self;
    }
}

impl Component for KeyHints {
    fn render(KeyHints k, Canvas cv, Ctx ctx) {
        let x = 0;
        let i = 0;
        while i < k.keys.len() {
            if i > 0 {
                x = x + 2;
            }
            x = cv.put(x, 0, k.keys[i], ctx.theme.accent.bold());
            x = cv.put(x + 1, 0, k.descriptions[i], ctx.theme.muted);
            i++;
        }
    }

    fn measure(KeyHints k, Size max) -> Size {
        let w = 0;
        let i = 0;
        while i < k.keys.len() {
            w = w + width(k.keys[i]) + 1 + width(k.descriptions[i]) + 2;
            i++;
        }
        return size(imin(max.w, imax(w - 2, 0)), imin(1, max.h));
    }

    fn constraint(KeyHints k) -> Constraint {
        return Constraint::Fixed(1);
    }
}

/// Start with `key_hints().add("q", "quit").add("?", "help")`.
fn key_hints() -> KeyHints {
    return new KeyHints(Vec::new(), Vec::new());
}

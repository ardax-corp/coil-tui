// Text and rules.
use cli::style::Style;
use cli::width::width;
use cli::width::wrap;
use text::Searchable;
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

/// Text: fixed (`content`) or computed on every draw (`source`), word
/// wrapped by default, sized to its content.
shared class Text {
    /// The text when not `dynamic`; `\n` starts a new line.
    pub content: string,
    /// Called on every draw instead of using `content` when `dynamic`.
    pub source: fn() -> string,
    // Not `Option<fn() -> string>`: coil-lang issue 1991.

    /// Whether `source` is called instead of using `content`.
    pub dynamic: bool,
    /// `None` uses the theme's text style.
    pub style: Option<Style>,
    /// Horizontal alignment of each line (`Start` by default).
    pub align: Align,
    /// Wrap at word boundaries; otherwise each line is cut with "…".
    pub wrapped: bool,
}

impl Text {
    /// Fixed, wrapped, left-aligned `content` in the theme's text style.
    pub static fn new(string content) -> Text {
        return new Text(content, fn () => "", false, Option::None, Align::Start, true);
    }

    /// The text as it would be drawn now.
    pub fn current() -> string {
        if self.dynamic {
            let f = self.source;
            return f();
        }
        return self.content;
    }

    /// The lines drawn in `cols` columns.
    pub fn lines(int cols) -> Vec<string> {
        let s = self.current();
        if self.wrapped {
            return wrap(s, imax(cols, 1));
        }
        let out: Vec<string> = s.split("\n");
        return out;
    }

    /// Draw in `s` instead of the theme's text style (builder style).
    pub fn styled(Style s) -> Text {
        self.style = Option::Some(s);
        return self;
    }

    /// Align each line by `a` (builder style).
    pub fn aligned(Align a) -> Text {
        self.align = a;
        return self;
    }

    /// Do not wrap: each line is cut with "…" (builder style).
    pub fn nowrap() -> Text {
        self.wrapped = false;
        return self;
    }
}

impl Component for Text {
    fn render(Text t, Canvas cv, Ctx ctx) {
        let st = t.style ?? ctx.theme.text;
        let lines = t.lines(cv.w());
        let y = 0;
        while y < lines.len() && y < cv.h() {
            cv.put_in(0, y, cv.w(), lines[y], st, t.align);
            y++;
        }
    }

    fn measure(Text t, Size max) -> Size {
        let lines = t.lines(max.w);
        let w = 0;
        for l in lines {
            w = imax(w, width(l));
        }
        return size(imin(w, max.w), imin(lines.len(), max.h));
    }

    fn constraint(Text t) -> Constraint {
        return Constraint::Auto;
    }
}

/// A text node showing `s`, word wrapped and sized to its content.
///
/// # Examples
///
/// ```
/// use tui::testing::harness;
/// use tui::widgets::layout::column;
/// use tui::widgets::text::{rule, text};
/// # use tests::assert;
/// let h = harness(column([text("one two three"), rule("End")]), 9, 3);
/// assert!(h.row(0) == "one two  ");
/// assert!(h.row(1) == "three    ");
/// assert!(h.row(2) == "─ End ───");
/// ```
fn text(string s) -> Node {
    return mount(Text::new(s));
}

/// A text node showing `s` in style `st`.
fn styled(string s, Style st) -> Node {
    return mount(Text::new(s).styled(st));
}

/// Text recomputed on every draw: `text_fn(fn () use (m) => m.status)`.
fn text_fn(fn() -> string f) -> Node {
    let t = Text::new("");
    t.source = f;
    t.dynamic = true;
    return mount(t);
}

/// A horizontal line, with an optional label at its start.
shared class Rule {
    /// Text drawn near the start of the line ("" for none).
    pub label: string,
    /// The line character (`─`).
    pub ch: string,
    /// `None` uses the theme's border style.
    pub style: Option<Style>,
}

impl Component for Rule {
    fn render(Rule r, Canvas cv, Ctx ctx) {
        let st = r.style ?? ctx.theme.border;
        cv.hline(0, 0, cv.w(), r.ch, st);
        if r.label != "" {
            cv.put_in(1, 0, cv.w() - 2, " " + r.label + " ", ctx.theme.title, Align::Start);
        }
    }

    fn measure(Rule r, Size max) -> Size {
        return size(max.w, imin(1, max.h));
    }

    fn constraint(Rule r) -> Constraint {
        return Constraint::Fixed(1);
    }
}

/// A one-row horizontal rule with `label` at its start ("" for a plain
/// line).
fn rule(string label) -> Node {
    return mount(new Rule(label, "─", Option::None));
}

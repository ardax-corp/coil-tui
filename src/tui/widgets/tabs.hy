// Pages behind a row of titles.
use cli::keys::Event;
use cli::keys::MouseKind;
use cli::keys::MouseButton;
use cli::keys::describe_key;
use cli::width::width;
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::rect;
use tui::geom::size;
use tui::geom::imax;
use tui::geom::imin;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;

/// A title bar over pages, one shown at a time. With the bar focused,
/// Left/Right switch; Ctrl-PageUp/PageDown switch from anywhere inside;
/// clicking a title switches to it.
shared class Tabs {
    pub titles: Vec<string>,
    pub pages: Vec<Node>,
    pub active: int,
    pub on_change: fn(int, Ctx) -> (),
    /// Start column of each title in the last frame (and the end).
    pub stops: Vec<int>,
}

impl Tabs {
    pub static fn new(Vec<string> titles, Vec<Node> pages) -> Tabs {
        let t = new Tabs(titles, pages, 0, fn (int i, Ctx c) {}, Vec::new());
        t.show();
        return t;
    }

    pub fn show() {
        let i = 0;
        while i < self.pages.len() {
            self.pages[i].visible = i == self.active;
            i++;
        }
    }

    /// Switch to page `i`; true when it changed.
    pub fn select(int i, Ctx ctx) -> bool {
        if i < 0 || i >= self.pages.len() || i == self.active {
            return false;
        }
        self.active = i;
        self.show();
        let f = self.on_change;
        f(i, ctx);
        return true;
    }

    pub fn on_change(fn(int, Ctx) -> () f) -> Tabs {
        self.on_change = f;
        return self;
    }
}

impl Component for Tabs {
    fn render(Tabs t, Canvas cv, Ctx ctx) {
        t.show();
        t.stops = Vec::new();
        let x = 0;
        let i = 0;
        while i < t.titles.len() {
            if i > 0 {
                x = cv.put(x, 0, "│", ctx.theme.border);
            }
            t.stops.push(x);
            let st = ctx.theme.muted;
            if i == t.active {
                st = ctx.theme.title;
                if ctx.has_focus() {
                    st = ctx.theme.selection;
                }
            }
            x = cv.put(x, 0, " " + t.titles[i] + " ", st);
            i++;
        }
        t.stops.push(x);
        if ctx.has_focus() && t.active < t.stops.len() - 1 {
            cv.cursor(t.stops[t.active] + 1, 0);
        }
    }

    fn children(Tabs t) -> Vec<Node> {
        return t.pages;
    }

    fn arrange(Tabs t, Rect area) -> Vec<Rect> {
        let out: Vec<Rect> = Vec::new();
        for p in t.pages {
            out.push(rect(0, 1, area.w, area.h - 1));
        }
        return out;
    }

    fn measure(Tabs t, Size max) -> Size {
        let w = 0;
        for title in t.titles {
            w = w + width(title) + 3;
        }
        let h = 0;
        for p in t.pages {
            let m = p.measure(size(max.w, max.h - 1));
            w = imax(w, m.w);
            h = imax(h, m.h);
        }
        return size(imin(max.w, w), imin(max.h, h + 1));
    }

    fn focusable(Tabs t) -> bool {
        return true;
    }

    fn handle(Tabs t, Event e, Ctx ctx) -> bool {
        return match e {
            Event::Key(k) => {
                let spec = describe_key(k);
                if spec == "ctrl+pagedown" {
                    t.select((t.active + 1) % imax(t.pages.len(), 1), ctx);
                    return true;
                }
                if spec == "ctrl+pageup" {
                    t.select((t.active - 1 + t.pages.len()) % imax(t.pages.len(), 1), ctx);
                    return true;
                }
                if !ctx.has_focus() {
                    return false;
                }
                if spec == "right" {
                    return t.select(t.active + 1, ctx);
                }
                if spec == "left" {
                    return t.select(t.active - 1, ctx);
                }
                return false;
            },
            Event::Mouse(m) => {
                let (x, y) = ctx.local(m);
                let press = match m.kind {
                    MouseKind::Press => true,
                    default => false,
                };
                if !press || y != 0 {
                    return false;
                }
                let i = 0;
                while i + 1 < t.stops.len() {
                    if x >= t.stops[i] && x < t.stops[i + 1] {
                        t.select(i, ctx);
                    }
                    i++;
                }
                return true;
            },
            default => false,
        };
    }
}

fn tabs(Vec<string> titles, Vec<Node> pages) -> Node {
    return mount(Tabs::new(titles, pages));
}

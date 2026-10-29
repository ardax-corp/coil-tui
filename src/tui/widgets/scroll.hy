// A viewport onto a child taller than the space it gets.
use cli::keys::{Event, MouseEvent, MouseButton, describe_key};
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::rect;
use tui::geom::size;
use tui::geom::imax;
use tui::geom::imin;
use tui::geom::clamp;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::node::contains;
use tui::node::has_focusable;
use tui::widgets::list::scrollbar;

/// Shows `child` at its measured height through a window, scrolled by
/// PageUp/PageDown, the wheel, and (when the scroll itself has focus,
/// because nothing inside can take it) Up/Down/Home/End. Keeps the
/// focused node inside it in view.
shared class Scroll {
    pub child: Node,
    pub kids: Vec<Node>,
    pub offset: int,
    pub content_h: int,
    pub view_h: int,
    /// Absolute row of the content's top in the last frame.
    pub content_top: int,
}

impl Scroll {
    pub static fn new(Node child) -> Scroll {
        let kids: Vec<Node> = Vec::new();
        kids.push(child);
        return new Scroll(child, kids, 0, 0, 0, 0);
    }

    pub fn scroll_to(int y) {
        self.offset = clamp(y, 0, imax(self.content_h - self.view_h, 0));
    }

    pub fn scroll_by(int n) {
        self.scroll_to(self.offset + n);
    }

    /// Scroll so the focused node (when it is inside) is visible.
    pub fn follow(Ctx ctx) {
        match ctx.focused {
            Option::Some(f) => {
                if f != self.child && contains(self.child, f) {
                    let y = f.rect.y - self.content_top;
                    if y < self.offset {
                        self.offset = y;
                    } else if y + f.rect.h > self.offset + self.view_h {
                        self.offset = y + f.rect.h - self.view_h;
                    }
                }
            },
            Option::None => {},
        }
    }
}

impl Component for Scroll {
    fn render(Scroll s, Canvas cv, Ctx ctx) {
        s.view_h = cv.h();
        s.content_h = s.child.measure(size(cv.w() - 1, 100000)).h;
        s.follow(ctx);
        s.scroll_to(s.offset);
        s.content_top = cv.area.y - s.offset;
        scrollbar(cv, 0, cv.h(), s.content_h, s.offset, ctx.theme.muted, ctx.theme.text);
    }

    fn children(Scroll s) -> Vec<Node> {
        return s.kids;
    }

    fn arrange(Scroll s, Rect area) -> Vec<Rect> {
        let w = area.w;
        if s.content_h > area.h {
            w = w - 1;
        }
        let out: Vec<Rect> = Vec::new();
        out.push(rect(0, -s.offset, w, imax(s.content_h, area.h)));
        return out;
    }

    fn measure(Scroll s, Size max) -> Size {
        return s.child.measure(max);
    }

    fn focusable(Scroll s) -> bool {
        return !has_focusable(s.child);
    }

    fn handle(Scroll s, Event e, Ctx ctx) -> bool {
        let page = imax(s.view_h - 1, 1);
        return match e {
            Event::Key(k) => {
                let spec = describe_key(k);
                if spec == "pageup" {
                    s.scroll_by(-page);
                    return true;
                }
                if spec == "pagedown" {
                    s.scroll_by(page);
                    return true;
                }
                if !ctx.has_focus() {
                    return false;
                }
                if spec == "up" {
                    s.scroll_by(-1);
                } else if spec == "down" {
                    s.scroll_by(1);
                } else if spec == "home" {
                    s.scroll_to(0);
                } else if spec == "end" {
                    s.scroll_to(s.content_h);
                } else {
                    return false;
                }
                return true;
            },
            Event::Mouse(m) => match m.button {
                MouseButton::WheelUp => {
                    s.scroll_by(-3);
                    return true;
                },
                MouseButton::WheelDown => {
                    s.scroll_by(3);
                    return true;
                },
                default => false,
            },
            default => false,
        };
    }
}

fn scroll(Node child) -> Node {
    return mount(Scroll::new(child));
}

// Containers: rows, columns, stacks, borders, padding, centring, space.
use cli::screen::BoxChars;
use cli::screen::light_box;
use cli::screen::rounded_box;
use cli::style::Style;
use cli::width::width;
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::Align;
use tui::geom::rect;
use tui::geom::size;
use tui::geom::imax;
use tui::geom::imin;
use tui::layout::Constraint;
use tui::layout::split;
use tui::layout::stack_rects;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;

// The sizes of `kids` when each may take up to `max`.
fn measures(Vec<Node> kids, Size max) -> Vec<Size> {
    let out: Vec<Size> = Vec::new();
    for k in kids {
        if k.visible {
            out.push(k.measure(max));
        } else {
            out.push(size(0, 0));
        }
    }
    return out;
}

/// Children side by side (`horizontal`) or one under another, sized by
/// their constraints.
shared class Flex {
    /// The children, in order.
    pub kids: Vec<Node>,
    /// Side by side (`true`) or one under another.
    pub horizontal: bool,
    /// Cells between neighbours.
    pub gap: int,
    /// Cross-axis placement of children (default `Stretch`).
    pub align: Align,
}

impl Flex {
    /// A row (`horizontal`) or column of `kids`, no gap, children stretched
    /// on the cross axis.
    pub static fn new(bool horizontal, Vec<Node> kids) -> Flex {
        return new Flex(kids, horizontal, 0, Align::Stretch);
    }

    /// Visible children (hidden ones take no space).
    pub fn shown() -> Vec<Node> {
        let out: Vec<Node> = Vec::new();
        for k in self.kids {
            if k.visible {
                out.push(k);
            }
        }
        return out;
    }
}

impl Component for Flex {
    fn render(Flex f, Canvas cv, Ctx ctx) {}

    fn children(Flex f) -> Vec<Node> {
        return f.kids;
    }

    fn measure(Flex f, Size max) -> Size {
        let shown = f.shown();
        let ms = measures(shown, max);
        let main = 0;
        let cross = 0;
        let i = 0;
        while i < shown.len() {
            let m = ms[i];
            let along = m.h;
            let across = m.w;
            if f.horizontal {
                along = m.w;
                across = m.h;
            }
            along = match shown[i].constraint {
                Constraint::Fixed(n) => n,
                default => along,
            };
            main = main + along;
            cross = imax(cross, across);
            i++;
        }
        if shown.len() > 1 {
            main = main + f.gap * (shown.len() - 1);
        }
        if f.horizontal {
            return size(imin(main, max.w), imin(cross, max.h));
        }
        return size(imin(cross, max.w), imin(main, max.h));
    }

    fn arrange(Flex f, Rect area) -> Vec<Rect> {
        let shown = f.shown();
        let ms = measures(shown, area.size());
        let cs: Vec<Constraint> = Vec::new();
        let nat: Vec<int> = Vec::new();
        let cross: Vec<int> = Vec::new();
        let i = 0;
        while i < shown.len() {
            cs.push(shown[i].constraint);
            if f.horizontal {
                nat.push(ms[i].w);
                cross.push(ms[i].h);
            } else {
                nat.push(ms[i].h);
                cross.push(ms[i].w);
            }
            i++;
        }
        let total = area.h;
        if f.horizontal {
            total = area.w;
        }
        let sizes = split(total, cs, nat, f.gap);
        let placed = stack_rects(area, f.horizontal, sizes, f.gap, cross, f.align);
        // Back to one rect per child, hidden ones included.
        let out: Vec<Rect> = Vec::new();
        let j = 0;
        for k in f.kids {
            if k.visible {
                out.push(placed[j]);
                j++;
            } else {
                out.push(rect(0, 0, 0, 0));
            }
        }
        return out;
    }
}

// The container functions take a `Vec<Node>` (`column([a, b])`) rather
// than `Node... kids`: a typed variadic cannot be called from another
// module yet (coil-lang issue 1990).

/// Children left to right: `row([a, b, c])`, each sized on the main
/// axis by its node's constraint (`fixed`, `fill`, `auto`, ...).
///
/// # Examples
///
/// ```
/// use tui::testing::harness;
/// use tui::widgets::layout::{block, column, row, spacer};
/// use tui::widgets::text::text;
/// # use tests::assert;
/// let top = row([text("L").fixed(3), text("R").fill(1)]).fixed(1);
/// let h = harness(block("Box", column([top, spacer()])), 10, 4);
/// assert!(h.row(0) == "┌ Box ───┐");
/// assert!(h.row(1) == "│L  R    │");
/// assert!(h.row(3) == "└────────┘");
/// ```
fn row(Vec<Node> kids) -> Node {
    return mount(Flex::new(true, kids));
}

/// Children top to bottom: `column([a, b, c])`.
fn column(Vec<Node> kids) -> Node {
    return mount(Flex::new(false, kids));
}

/// A row or column you keep a reference to (to add children later, or
/// set `gap` and `align`): `let f = flex(false); mount(f)`.
fn flex(bool horizontal) -> Flex {
    return Flex::new(horizontal, Vec::new());
}

impl Flex {
    /// Append a child (builder style).
    pub fn add(Node n) -> Flex {
        self.kids.push(n);
        return self;
    }

    /// Put `gap` cells between neighbours (builder style).
    pub fn spaced(int gap) -> Flex {
        self.gap = gap;
        return self;
    }

    /// Place children on the cross axis by `a` (builder style).
    pub fn aligned(Align a) -> Flex {
        self.align = a;
        return self;
    }
}

/// Children drawn on top of each other, each over the whole area (later
/// ones on top).
shared class Stack {
    /// The layers, bottom first.
    pub kids: Vec<Node>,
}

impl Component for Stack {
    fn render(Stack s, Canvas cv, Ctx ctx) {}

    fn children(Stack s) -> Vec<Node> {
        return s.kids;
    }

    fn measure(Stack s, Size max) -> Size {
        let w = 0;
        let h = 0;
        for m in measures(s.kids, max) {
            w = imax(w, m.w);
            h = imax(h, m.h);
        }
        return size(w, h);
    }
}

/// `kids` drawn over each other, each over the whole area.
fn stack(Vec<Node> kids) -> Node {
    return mount(new Stack(kids));
}

/// Space around one child.
shared class Pad {
    /// The padded child.
    pub child: Node,
    /// Blank rows above.
    pub top: int,
    /// Blank columns on the right.
    pub right: int,
    /// Blank rows below.
    pub bottom: int,
    /// Blank columns on the left.
    pub left: int,
    /// `[child]`, for `children`.
    pub kids: Vec<Node>,
}

impl Component for Pad {
    fn render(Pad p, Canvas cv, Ctx ctx) {}

    fn children(Pad p) -> Vec<Node> {
        return p.kids;
    }

    fn measure(Pad p, Size max) -> Size {
        let m = p.child.measure(size(max.w - p.left - p.right, max.h - p.top - p.bottom));
        return size(imin(max.w, m.w + p.left + p.right), imin(max.h, m.h + p.top + p.bottom));
    }

    fn arrange(Pad p, Rect area) -> Vec<Rect> {
        let out: Vec<Rect> = Vec::new();
        out.push(area.inset(p.top, p.right, p.bottom, p.left));
        return out;
    }

    // Fixed sizes are along a parent's main axis, which may be either.
    fn constraint(Pad p) -> Constraint {
        return grow(p.child.constraint, imax(p.top + p.bottom, p.left + p.right));
    }
}

// `c` for a wrapper that adds `by` cells around its child: a fixed
// size grows, anything else is kept.
fn grow(Constraint c, int by) -> Constraint {
    return match c {
        Constraint::Fixed(n) => Constraint::Fixed(n + by),
        default => c,
    };
}

fn one(Node n) -> Vec<Node> {
    let v: Vec<Node> = Vec::new();
    v.push(n);
    return v;
}

/// `child` with `v` blank rows above and below and `h` blank columns on
/// each side.
fn pad(int v, int h, Node child) -> Node {
    return mount(new Pad(child, v, h, v, h, one(child)));
}

/// `child` at its measured size, aligned inside the area.
shared class Place {
    /// The placed child.
    pub child: Node,
    /// Horizontal alignment.
    pub ax: Align,
    /// Vertical alignment.
    pub ay: Align,
    /// `[child]`, for `children`.
    pub kids: Vec<Node>,
}

impl Component for Place {
    fn render(Place p, Canvas cv, Ctx ctx) {}

    fn children(Place p) -> Vec<Node> {
        return p.kids;
    }

    fn measure(Place p, Size max) -> Size {
        return p.child.measure(max);
    }

    fn arrange(Place p, Rect area) -> Vec<Rect> {
        let m = p.child.measure(area.size());
        let out: Vec<Rect> = Vec::new();
        out.push(area.place(m.w, m.h, p.ax, p.ay));
        return out;
    }
}

/// `child` at its measured size, centred in the area.
fn center(Node child) -> Node {
    return mount(new Place(child, Align::Center, Align::Center, one(child)));
}

/// `child` at its measured size, aligned by `ax` and `ay`.
fn align(Align ax, Align ay, Node child) -> Node {
    return mount(new Place(child, ax, ay, one(child)));
}

/// Empty space that takes what is left (`Fill(1)`).
shared class Spacer {
    /// Unused; the spacer has no settings.
    pub n: int,
}

impl Component for Spacer {
    fn render(Spacer s, Canvas cv, Ctx ctx) {}

    fn measure(Spacer s, Size max) -> Size {
        return size(0, 0);
    }
}

/// Empty space taking what is left in a row or column.
fn spacer() -> Node {
    return mount(new Spacer(0));
}

/// A border with an optional title around one child.
shared class Block {
    /// The bordered child.
    pub child: Node,
    /// Title on the top border ("" for none).
    pub title: string,
    /// Where the title sits on the top border.
    pub title_align: Align,
    /// The border characters (`light_box()` by default).
    pub chars: BoxChars,
    /// Blank cells inside the border.
    pub padding: int,
    /// Border style; `None` uses the theme (focused style when focus is
    /// inside).
    pub style: Option<Style>,
    /// `[child]`, for `children`.
    pub kids: Vec<Node>,
}

impl Block {
    /// `child` in a light border titled `title`, no padding.
    pub static fn new(string title, Node child) -> Block {
        return new Block(child, title, Align::Start, light_box(), 0, Option::None, one(child));
    }

    /// Use rounded corners (builder style).
    pub fn rounded() -> Block {
        self.chars = rounded_box();
        return self;
    }

    /// Leave `n` blank cells inside the border (builder style).
    pub fn padded(int n) -> Block {
        self.padding = n;
        return self;
    }

    /// Draw the border in `s` always (builder style).
    pub fn styled(Style s) -> Block {
        self.style = Option::Some(s);
        return self;
    }

    /// Place the title by `a` (builder style).
    pub fn title_at(Align a) -> Block {
        self.title_align = a;
        return self;
    }
}

impl Component for Block {
    fn render(Block b, Canvas cv, Ctx ctx) {
        let st = ctx.theme.border;
        if ctx.focus_within() {
            st = ctx.theme.border_focused;
        }
        st = b.style ?? st;
        cv.draw_box(0, 0, cv.w(), cv.h(), b.chars, st);
        if b.title != "" && cv.w() > 4 {
            let t = " " + b.title + " ";
            cv.put_in(1, 0, cv.w() - 2, t, ctx.theme.title, b.title_align);
        }
    }

    fn children(Block b) -> Vec<Node> {
        return b.kids;
    }

    fn measure(Block b, Size max) -> Size {
        let edge = 2 + 2 * b.padding;
        let m = b.child.measure(size(max.w - edge, max.h - edge));
        let w = imax(m.w + edge, width(b.title) + 4);
        return size(imin(max.w, w), imin(max.h, m.h + edge));
    }

    fn arrange(Block b, Rect area) -> Vec<Rect> {
        let out: Vec<Rect> = Vec::new();
        out.push(area.shrink(1 + b.padding));
        return out;
    }

    fn constraint(Block b) -> Constraint {
        return grow(b.child.constraint, 2 + 2 * b.padding);
    }
}

/// `child` in a light border with `title` ("" for none).
fn block(string title, Node child) -> Node {
    return mount(Block::new(title, child));
}

// Selectable, scrolling lists and tables.
use cli::keys::Event;
use cli::keys::MouseEvent;
use cli::keys::MouseKind;
use cli::keys::MouseButton;
use cli::keys::describe_key;
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
use tui::geom::clamp;
use tui::layout::Constraint;
use tui::layout::split;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;

/// A cursor over `count` rows shown `height` at a time: the selected
/// row and the first visible one.
class Selection {
    pub selected: int,
    pub offset: int,
}

fn selection() -> Selection {
    return new Selection(0, 0);
}

impl Selection {
    /// Keep both in range and the selected row in view.
    pub fn fit(int count, int height) {
        if count == 0 {
            self.selected = 0;
            self.offset = 0;
            return;
        }
        self.selected = clamp(self.selected, 0, count - 1);
        let h = imax(height, 1);
        if self.selected < self.offset {
            self.offset = self.selected;
        }
        if self.selected >= self.offset + h {
            self.offset = self.selected - h + 1;
        }
        self.offset = clamp(self.offset, 0, imax(count - h, 0));
    }

    /// Apply a navigation key; true when it was one (even at an edge).
    pub fn key(string k, int count, int height) -> bool {
        let page = imax(height - 1, 1);
        if k == "up" || k == "k" {
            self.selected--;
        } else if k == "down" || k == "j" {
            self.selected++;
        } else if k == "pageup" {
            self.selected = self.selected - page;
        } else if k == "pagedown" {
            self.selected = self.selected + page;
        } else if k == "home" {
            self.selected = 0;
        } else if k == "end" {
            self.selected = count - 1;
        } else {
            return false;
        }
        self.fit(count, height);
        return true;
    }

    /// Scroll the view by `n` rows without moving the selection out of
    /// it.
    pub fn scroll(int n, int count, int height) {
        let h = imax(height, 1);
        self.offset = clamp(self.offset + n, 0, imax(count - h, 0));
        self.selected = clamp(self.selected, self.offset, self.offset + h - 1);
        self.fit(count, height);
    }
}

fn key_spec(Event e) -> string {
    return match e {
        Event::Key(k) => describe_key(k),
        default => "",
    };
}

/// For a mouse event: `0` none, `1` left press, `2` wheel up, `3`
/// wheel down.
fn mouse_action(MouseEvent m) -> int {
    return match m.button {
        MouseButton::WheelUp => 2,
        MouseButton::WheelDown => 3,
        MouseButton::Left => match m.kind {
            MouseKind::Press => 1,
            default => 0,
        },
        default => 0,
    };
}

/// A vertical scrollbar in the last column of `cv` for `count` rows
/// starting at `offset`, `h` shown. Nothing when everything fits.
fn scrollbar(Canvas cv, int top, int h, int count, int offset, Style track, Style thumb) {
    if count <= h || h <= 0 {
        return;
    }
    let x = cv.w() - 1;
    cv.vline(x, top, h, "│", track);
    let size = imax(1, h * h / count);
    let pos = 0;
    if count > h {
        pos = (h - size) * offset / (count - h);
    }
    cv.vline(x, top + pos, size, "┃", thumb);
}

/// A list of text rows with one selected. Up/Down/PageUp/PageDown/
/// Home/End move, the wheel scrolls, a click selects, Enter activates.
class List {
    pub items: Vec<string>,
    pub sel: Selection,
    /// Drawn before the selected row ("" for none; other rows get as
    /// many spaces).
    pub marker: string,
    pub on_select: fn(int, Ctx) -> (),
    pub on_activate: fn(int, Ctx) -> (),
    /// Rows shown in the last frame.
    pub height: int,
}

impl List {
    pub static fn new(Vec<string> items) -> List {
        return new List(items, selection(), "", fn (int i, Ctx c) {}, fn (int i, Ctx c) {}, 1);
    }

    pub fn selected() -> int {
        return self.sel.selected;
    }

    /// The selected item ("" when the list is empty).
    pub fn value() -> string {
        if self.items.len() == 0 {
            return "";
        }
        self.sel.fit(self.items.len(), self.height);
        return self.items[self.sel.selected];
    }

    pub fn select(int i) {
        self.sel.selected = i;
        self.sel.fit(self.items.len(), self.height);
    }

    pub fn marked(string m) -> List {
        self.marker = m;
        return self;
    }

    pub fn on_select(fn(int, Ctx) -> () f) -> List {
        self.on_select = f;
        return self;
    }

    pub fn on_activate(fn(int, Ctx) -> () f) -> List {
        self.on_activate = f;
        return self;
    }

    pub fn changed(int before, Ctx ctx) {
        if self.items.len() > 0 && self.sel.selected != before {
            let f = self.on_select;
            f(self.sel.selected, ctx);
        }
    }

    pub fn activate(Ctx ctx) {
        if self.items.len() > 0 {
            let f = self.on_activate;
            f(self.sel.selected, ctx);
        }
    }
}

impl Component for List {
    fn render(List l, Canvas cv, Ctx ctx) {
        l.height = cv.h();
        let n = l.items.len();
        l.sel.fit(n, cv.h());
        let bar = 0;
        if n > cv.h() {
            bar = 1;
        }
        let w = cv.w() - bar;
        let pad = "";
        let mw = width(l.marker);
        while width(pad) < mw {
            pad = pad + " ";
        }
        let y = 0;
        while y < cv.h() && l.sel.offset + y < n {
            let i = l.sel.offset + y;
            let st = ctx.theme.text;
            let lead = pad;
            if i == l.sel.selected {
                lead = l.marker;
                st = ctx.theme.selection_unfocused;
                if ctx.has_focus() {
                    st = ctx.theme.selection;
                }
                cv.fill(0, y, w, 1, " ", st);
            }
            let x = cv.put(0, y, lead, st);
            cv.put_in(x, y, w - x, l.items[i], st, Align::Start);
            y++;
        }
        scrollbar(cv, 0, cv.h(), n, l.sel.offset, ctx.theme.muted, ctx.theme.text);
    }

    fn measure(List l, Size max) -> Size {
        let w = 0;
        for it in l.items {
            w = imax(w, width(it));
        }
        return size(imin(max.w, w + width(l.marker) + 1), imin(max.h, l.items.len()));
    }

    fn focusable(List l) -> bool {
        return true;
    }

    fn handle(List l, Event e, Ctx ctx) -> bool {
        let n = l.items.len();
        let before = l.sel.selected;
        let k = key_spec(e);
        if k == "enter" {
            l.activate(ctx);
            return true;
        }
        if l.sel.key(k, n, l.height) {
            l.changed(before, ctx);
            return true;
        }
        return match e {
            Event::Mouse(m) => {
                let a = mouse_action(m);
                if a == 2 {
                    l.sel.scroll(-3, n, l.height);
                } else if a == 3 {
                    l.sel.scroll(3, n, l.height);
                } else if a == 1 {
                    let (x, y) = ctx.local(m);
                    let i = l.sel.offset + y;
                    if i < n {
                        if i == l.sel.selected {
                            l.activate(ctx);
                        }
                        l.sel.selected = i;
                    }
                }
                l.changed(before, ctx);
                return a != 0;
            },
            default => false,
        };
    }
}

fn list(Vec<string> items) -> List {
    return List::new(items);
}

/// A table column: header, width constraint and alignment.
class TableColumn {
    pub title: string,
    pub width: Constraint,
    pub align: Align,
}

fn table_column(string title, Constraint w) -> TableColumn {
    return new TableColumn(title, w, Align::Start);
}

/// Rows of cells under a header, with one row selected; keys and mouse
/// as for `List`.
class Table {
    pub columns: Vec<TableColumn>,
    pub rows: Vec<Vec<string>>,
    pub sel: Selection,
    pub header: bool,
    pub on_select: fn(int, Ctx) -> (),
    pub on_activate: fn(int, Ctx) -> (),
    pub height: int,
}

impl Table {
    pub static fn new(Vec<TableColumn> columns, Vec<Vec<string>> rows) -> Table {
        return new Table(
            columns,
            rows,
            selection(),
            true,
            fn (int i, Ctx c) {},
            fn (int i, Ctx c) {},
            1,
        );
    }

    pub fn selected() -> int {
        return self.sel.selected;
    }

    pub fn on_select(fn(int, Ctx) -> () f) -> Table {
        self.on_select = f;
        return self;
    }

    pub fn on_activate(fn(int, Ctx) -> () f) -> Table {
        self.on_activate = f;
        return self;
    }

    /// Column widths for `w` cells: `Auto` columns size to their widest
    /// cell, one space between columns.
    pub fn widths(int w) -> Vec<int> {
        let cs: Vec<Constraint> = Vec::new();
        let nat: Vec<int> = Vec::new();
        let c = 0;
        while c < self.columns.len() {
            let col = self.columns[c];
            cs.push(col.width);
            let m = width(col.title);
            for r in self.rows {
                if c < r.len() {
                    m = imax(m, width(r[c]));
                }
            }
            nat.push(m);
            c++;
        }
        return split(w, cs, nat, 1);
    }

    pub fn body_height() -> int {
        if self.header {
            return imax(self.height - 1, 1);
        }
        return self.height;
    }
}

impl Component for Table {
    fn render(Table t, Canvas cv, Ctx ctx) {
        t.height = cv.h();
        let n = t.rows.len();
        let top = 0;
        if t.header {
            top = 1;
        }
        let bh = cv.h() - top;
        t.sel.fit(n, bh);
        let bar = 0;
        if n > bh {
            bar = 1;
        }
        let ws = t.widths(cv.w() - bar);
        if t.header {
            let x = 0;
            let c = 0;
            while c < t.columns.len() {
                let col = t.columns[c];
                cv.put_in(x, 0, ws[c], col.title, ctx.theme.title, col.align);
                x = x + ws[c] + 1;
                c++;
            }
        }
        let y = 0;
        while y < bh && t.sel.offset + y < n {
            let i = t.sel.offset + y;
            let st = ctx.theme.text;
            if i == t.sel.selected {
                st = ctx.theme.selection_unfocused;
                if ctx.has_focus() {
                    st = ctx.theme.selection;
                }
                cv.fill(0, top + y, cv.w() - bar, 1, " ", st);
            }
            let r = t.rows[i];
            let x = 0;
            let c = 0;
            while c < t.columns.len() {
                if c < r.len() {
                    cv.put_in(x, top + y, ws[c], r[c], st, t.columns[c].align);
                }
                x = x + ws[c] + 1;
                c++;
            }
            y++;
        }
        scrollbar(cv, top, bh, n, t.sel.offset, ctx.theme.muted, ctx.theme.text);
    }

    fn measure(Table t, Size max) -> Size {
        let w = t.columns.len() - 1;
        for x in t.widths(10000) {
            w = w + x;
        }
        let h = t.rows.len();
        if t.header {
            h++;
        }
        return size(imin(max.w, w), imin(max.h, h));
    }

    fn focusable(Table t) -> bool {
        return true;
    }

    fn handle(Table t, Event e, Ctx ctx) -> bool {
        let n = t.rows.len();
        let before = t.sel.selected;
        let k = key_spec(e);
        let done = false;
        if k == "enter" {
            if n > 0 {
                let f = t.on_activate;
                f(t.sel.selected, ctx);
            }
            return true;
        }
        if t.sel.key(k, n, t.body_height()) {
            done = true;
        } else {
            match e {
                Event::Mouse(m) => {
                    let a = mouse_action(m);
                    if a == 2 {
                        t.sel.scroll(-3, n, t.body_height());
                    } else if a == 3 {
                        t.sel.scroll(3, n, t.body_height());
                    } else if a == 1 {
                        let (x, y) = ctx.local(m);
                        let top = 0;
                        if t.header {
                            top = 1;
                        }
                        let i = t.sel.offset + y - top;
                        if y >= top && i < n {
                            t.sel.selected = i;
                        }
                    }
                    done = a != 0;
                },
                default => {},
            }
        }
        if done && n > 0 && t.sel.selected != before {
            let f = t.on_select;
            f(t.sel.selected, ctx);
        }
        return done;
    }
}

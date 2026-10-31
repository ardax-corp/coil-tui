// Drawing in local coordinates onto a frame's cell buffer, clipped to the
// component's area.
use string::{to_bytes, slice_bytes};
use cli::screen::Buffer;
use cli::screen::BoxChars;
use cli::screen::Cell;
use cli::style::Style;
use cli::width::char_width;
use cli::width::decode_at;
use cli::width::seq_len;
use cli::width::width;
use cli::width::truncate;
use tui::geom::{Rect, Align, rect};

/// One frame being drawn: the buffer plus where the focused component
/// wants the terminal cursor (absolute cell, or none).
shared class Frame {
    /// The cells being drawn.
    pub buf: Buffer,
    /// Column of the requested terminal cursor (with `has_cursor`).
    pub cursor_x: int,
    /// Row of the requested terminal cursor (with `has_cursor`).
    pub cursor_y: int,
    /// Whether a component asked for the cursor this frame.
    pub has_cursor: bool,
}

/// A frame drawing into `buf`, with no cursor requested.
fn frame(Buffer buf) -> Frame {
    return new Frame(buf, 0, 0, false);
}

fn piece(string s, int from, int to) -> string {
    return match slice_bytes(s, from, to) {
        Result::Ok(t) => t,
        Result::Err(_) => "",
    };
}

/// A view onto a `Frame`: local (0, 0) is `area`'s corner, and nothing
/// is drawn outside `clip` (absolute coordinates, inside `area`). A
/// component's `render` gets one sized to its node.
///
/// # Examples
///
/// ```
/// use tui::canvas::{canvas, frame};
/// use tui::geom::{Align, rect};
/// use cli::screen::buffer;
/// use cli::style::plain;
/// # use tests::assert;
/// let f = frame(buffer(12, 2));
/// let c = canvas(f).sub(rect(2, 0, 6, 2));
/// c.put(0, 0, "clipped text", plain());
/// c.put_in(0, 1, 6, "ok", plain(), Align::End);
/// assert!(f.buf.row_text(0) == "  clippe    ");
/// assert!(f.buf.row_text(1) == "      ok    ");
/// ```
class Canvas {
    /// The frame drawn into.
    pub frame: Frame,
    /// The component's area, in absolute cells.
    pub area: Rect,
    /// Where drawing lands, in absolute cells (inside `area`).
    pub clip: Rect,
}

/// A canvas over the whole of `f`'s buffer.
fn canvas(Frame f) -> Canvas {
    let all = rect(0, 0, f.buf.cols, f.buf.rows);
    return new Canvas(f, all, all);
}

impl Canvas {
    /// Width of the area in cells.
    pub fn w() -> int {
        return self.area.w;
    }

    /// Height of the area in cells.
    pub fn h() -> int {
        return self.area.h;
    }

    /// The area in local coordinates.
    pub fn bounds() -> Rect {
        return rect(0, 0, self.area.w, self.area.h);
    }

    /// A canvas for the local rect `r`, clipped to this one.
    pub fn sub(Rect r) -> Canvas {
        let abs = r.offset(self.area.x, self.area.y);
        return new Canvas(self.frame, abs, self.clip.intersect(abs));
    }

    /// Whether local (`x`, `y`) is drawable.
    pub fn visible(int x, int y) -> bool {
        return self.clip.contains(self.area.x + x, self.area.y + y);
    }

    /// The cell at local (`x`, `y`) (a blank outside the buffer).
    pub fn get(int x, int y) -> Cell {
        return self.frame.buf.get(self.area.x + x, self.area.y + y);
    }

    /// Set one cell (ignored outside the clip).
    pub fn set(int x, int y, string text, Style style) {
        if self.visible(x, y) {
            self.frame.buf.set(self.area.x + x, self.area.y + y, text, style);
        }
    }

    /// Write `s` on row `y` from column `x`, clipped on both sides. Wide
    /// characters take two cells; one cut by the clip edge shows as a
    /// space. Zero-width marks join the cell before them. Returns the
    /// column after the text.
    pub fn put(int x, int y, string s, Style style) -> int {
        let b = to_bytes(s);
        let col = x;
        let i = 0;
        let last = -1;
        while i < b.len() {
            let n = seq_len(b[i] as int);
            let cp = decode_at(b, i);
            let ch = piece(s, i, i + n);
            let w = char_width(cp);
            if w == 0 {
                if last >= 0 && self.visible(last, y) {
                    let prev = self.get(last, y);
                    self.set(last, y, prev.text + ch, prev.style);
                }
            } else if w == 1 {
                self.set(col, y, ch, style);
                last = col;
                col++;
            } else {
                let a = self.visible(col, y);
                let z = self.visible(col + 1, y);
                if a && z {
                    self.set(col, y, ch, style);
                    self.set(col + 1, y, "", style);
                } else if a {
                    self.set(col, y, " ", style);
                } else if z {
                    self.set(col + 1, y, " ", style);
                }
                last = col;
                col = col + 2;
            }
            i = i + n;
        }
        return col;
    }

    /// `s` on row `y` within columns `x..x+w`, aligned by `a`, cut with
    /// "…" when it does not fit.
    pub fn put_in(int x, int y, int w, string s, Style style, Align a) -> int {
        if w <= 0 {
            return x;
        }
        let t = truncate(s, w, "…");
        let tw = width(t);
        let at = match a {
            Align::Center => x + (w - tw) / 2,
            Align::End => x + w - tw,
            default => x,
        };
        return self.put(at, y, t, style);
    }

    /// Fill a rect with `ch` (one column wide).
    pub fn fill(int x, int y, int w, int h, string ch, Style style) {
        let r = y;
        while r < y + h {
            let c = x;
            while c < x + w {
                self.set(c, r, ch, style);
                c++;
            }
            r++;
        }
    }

    /// Fill the whole area with blanks in `style` (a background).
    pub fn clear(Style style) {
        self.fill(0, 0, self.area.w, self.area.h, " ", style);
    }

    /// Restyle a rect, keeping its text: `style` is merged over each
    /// cell's own style.
    pub fn paint(int x, int y, int w, int h, Style style) {
        let r = y;
        while r < y + h {
            let c = x;
            while c < x + w {
                if self.visible(c, r) {
                    let cell = self.get(c, r);
                    self.set(c, r, cell.text, cell.style.merge(style));
                }
                c++;
            }
            r++;
        }
    }

    /// A horizontal line of `w` cells of `ch` from local (`x`, `y`).
    pub fn hline(int x, int y, int w, string ch, Style style) {
        self.fill(x, y, w, 1, ch, style);
    }

    /// A vertical line of `h` cells of `ch` from local (`x`, `y`).
    pub fn vline(int x, int y, int h, string ch, Style style) {
        self.fill(x, y, 1, h, ch, style);
    }

    /// A box outline; `w`, `h` include the border.
    pub fn draw_box(int x, int y, int w, int h, BoxChars bc, Style style) {
        if w < 2 || h < 2 {
            return;
        }
        self.set(x, y, bc.tl, style);
        self.set(x + w - 1, y, bc.tr, style);
        self.set(x, y + h - 1, bc.bl, style);
        self.set(x + w - 1, y + h - 1, bc.br, style);
        self.hline(x + 1, y, w - 2, bc.h, style);
        self.hline(x + 1, y + h - 1, w - 2, bc.h, style);
        self.vline(x, y + 1, h - 2, bc.v, style);
        self.vline(x + w - 1, y + 1, h - 2, bc.v, style);
    }

    /// Ask for the terminal cursor at local (`x`, `y`), when it is
    /// visible. The last request in a frame wins.
    pub fn cursor(int x, int y) {
        if self.visible(x, y) {
            self.frame.cursor_x = self.area.x + x;
            self.frame.cursor_y = self.area.y + y;
            self.frame.has_cursor = true;
        }
    }
}

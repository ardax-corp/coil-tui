// Rectangles and sizes in terminal cells.

/// A width and height in cells.
class Size {
    /// Width in cells.
    pub w: int,
    /// Height in cells.
    pub h: int,
}

/// A `w` by `h` size; negative values become 0.
fn size(int w, int h) -> Size {
    return new Size(max0(w), max0(h));
}

fn max0(int n) -> int {
    if n < 0 {
        return 0;
    }
    return n;
}

/// The smaller of `a` and `b`.
fn imin(int a, int b) -> int {
    if a < b {
        return a;
    }
    return b;
}

/// The larger of `a` and `b`.
fn imax(int a, int b) -> int {
    if a > b {
        return a;
    }
    return b;
}

/// Clamp `v` into `lo..=hi` (`lo` wins when `hi < lo`).
fn clamp(int v, int lo, int hi) -> int {
    return imax(lo, imin(v, hi));
}

/// Alignment on one axis.
enum Align {
    /// At the start: left or top.
    Start,
    /// Centred (an odd leftover cell goes after).
    Center,
    /// At the end: right or bottom.
    End,
    /// Take the whole axis.
    Stretch,
}

/// A rectangle of cells: top-left corner (`x`, `y`) and size. Width and
/// height are never negative. The right and bottom edges are exclusive.
///
/// # Examples
///
/// ```
/// use tui::geom::{Align, rect};
/// # use tests::assert;
/// let r = rect(2, 1, 10, 4);
/// assert!(r.right() == 12 && r.bottom() == 5);
/// assert!(r.contains(11, 4) && !r.contains(12, 4));
/// let inner = r.shrink(1);
/// assert!(inner.eq(rect(3, 2, 8, 2)));
/// let c = r.place(4, 2, Align::Center, Align::End);
/// assert!(c.eq(rect(5, 3, 4, 2)));
/// assert!(r.intersect(rect(20, 20, 3, 3)).is_empty());
/// ```
class Rect {
    /// Left column.
    pub x: int,
    /// Top row.
    pub y: int,
    /// Width in cells.
    pub w: int,
    /// Height in cells.
    pub h: int,
}

/// A rect at (`x`, `y`), `w` by `h`; a negative size becomes 0.
fn rect(int x, int y, int w, int h) -> Rect {
    return new Rect(x, y, max0(w), max0(h));
}

/// The empty rect at (0, 0).
fn empty() -> Rect {
    return rect(0, 0, 0, 0);
}

impl Rect {
    /// The column just past the right edge (`x + w`).
    pub fn right() -> int {
        return self.x + self.w;
    }

    /// The row just past the bottom edge (`y + h`).
    pub fn bottom() -> int {
        return self.y + self.h;
    }

    /// Whether the rect has no cells (zero width or height).
    pub fn is_empty() -> bool {
        return self.w == 0 || self.h == 0;
    }

    /// Width and height as a `Size`.
    pub fn size() -> Size {
        return new Size(self.w, self.h);
    }

    /// Whether both rects have the same corner and size.
    pub fn eq(Rect o) -> bool {
        return self.x == o.x && self.y == o.y && self.w == o.w && self.h == o.h;
    }

    /// Whether cell (`px`, `py`) is inside.
    pub fn contains(int px, int py) -> bool {
        return px >= self.x && py >= self.y && px < self.right() && py < self.bottom();
    }

    /// The overlap of two rects (empty, at this rect's corner, when they
    /// do not overlap).
    pub fn intersect(Rect o) -> Rect {
        let x0 = imax(self.x, o.x);
        let y0 = imax(self.y, o.y);
        let x1 = imin(self.right(), o.right());
        let y1 = imin(self.bottom(), o.bottom());
        if x1 <= x0 || y1 <= y0 {
            return rect(self.x, self.y, 0, 0);
        }
        return rect(x0, y0, x1 - x0, y1 - y0);
    }

    /// Moved by (`dx`, `dy`).
    pub fn offset(int dx, int dy) -> Rect {
        return rect(self.x + dx, self.y + dy, self.w, self.h);
    }

    /// Shrunk by `top`, `right`, `bottom`, `left` cells.
    pub fn inset(int top, int right, int bottom, int left) -> Rect {
        return rect(self.x + left, self.y + top, self.w - left - right, self.h - top - bottom);
    }

    /// Shrunk by `n` cells on every side.
    pub fn shrink(int n) -> Rect {
        return self.inset(n, n, n, n);
    }

    /// A `w` x `h` rect placed inside this one by `ax`, `ay` (clipped to
    /// this rect; `Stretch` takes the whole axis).
    pub fn place(int w, int h, Align ax, Align ay) -> Rect {
        let (px, pw) = place_axis(self.x, self.w, w, ax);
        let (py, ph) = place_axis(self.y, self.h, h, ay);
        return rect(px, py, pw, ph);
    }

    /// The same rect with (0, 0) as its corner.
    pub fn local() -> Rect {
        return rect(0, 0, self.w, self.h);
    }
}

// Start and length of `want` cells aligned within `start..start+len`.
fn place_axis(int start, int len, int want, Align a) -> (int, int) {
    let n = clamp(want, 0, len);
    return match a {
        Align::Start => (start, n),
        Align::Center => (start + (len - n) / 2, n),
        Align::End => (start + len - n, n),
        Align::Stretch => (start, len),
    };
}

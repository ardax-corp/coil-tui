// Dividing one axis between children by their constraints.
use tui::geom::{Rect, Align, rect};

/// How a row or column sizes a child on its main axis.
enum Constraint {
    /// Exactly `n` cells.
    Fixed(int),
    /// `p` percent of the space (after gaps).
    Percent(int),
    /// The child's own measured size.
    Auto,
    /// A share of what is left over, by weight.
    Fill(int),
    /// At least `n` cells, then grows like `Fill(1)`.
    Min(int),
    /// Grows like `Fill(1)`, up to `n` cells.
    Max(int),
}

// Base size before leftover space is shared out.
fn base_of(Constraint c, int avail, int natural) -> int {
    return match c {
        Constraint::Fixed(n) => pos(n),
        Constraint::Percent(p) => avail * pos(p) / 100,
        Constraint::Auto => pos(natural),
        Constraint::Min(n) => pos(n),
        default => 0,
    };
}

fn weight_of(Constraint c) -> int {
    return match c {
        Constraint::Fill(w) => pos(w),
        Constraint::Min(_) => 1,
        Constraint::Max(_) => 1,
        default => 0,
    };
}

// Upper bound on the leftover share (-1 = none).
fn cap_of(Constraint c) -> int {
    return match c {
        Constraint::Max(n) => pos(n),
        default => -1,
    };
}

fn pos(int n) -> int {
    if n < 0 {
        return 0;
    }
    return n;
}

// `total` split as `parts` proportionally to `weights`, flooring and
// handing the remainder out one cell at a time from the first part.
fn share(int total, Vec<int> weights) -> Vec<int> {
    let out: Vec<int> = Vec::new();
    let sum = 0;
    for w in weights {
        sum = sum + w;
    }
    let given = 0;
    for w in weights {
        let s = 0;
        if sum > 0 {
            s = total * w / sum;
        }
        out.push(s);
        given = given + s;
    }
    let left = total - given;
    let i = 0;
    while left > 0 && sum > 0 {
        if weights[i] > 0 {
            out[i] = out[i] + 1;
            left--;
        }
        i = (i + 1) % out.len();
    }
    return out;
}

/// Sizes along one axis for children with `cs` constraints and
/// `naturals` measured sizes (used by `Auto`), in `total` cells with
/// `gap` cells between neighbours.
///
/// Fixed, percent, auto and min sizes come first; when they do not fit
/// they are shrunk in proportion. What is left goes to fill, min and
/// max children by weight, with max children capped. Leftover space with
/// no fill child to take it stays unused at the end.
///
/// # Examples
///
/// ```
/// use tui::layout::{Constraint, split};
/// # use tests::assert;
/// let cs: Vec<Constraint> = [Constraint::Fixed(5), Constraint::Fill(1), Constraint::Fill(2)];
/// let none: Vec<int> = Vec::new();
/// let sizes = split(21, cs, none, 0);
/// assert!(sizes[0] == 5 && sizes[1] == 6 && sizes[2] == 10);
/// let gapped = split(21, cs, none, 2);
/// assert!(gapped[0] + gapped[1] + gapped[2] == 17);
/// ```
fn split(int total, Vec<Constraint> cs, Vec<int> naturals, int gap) -> Vec<int> {
    let n = cs.len();
    let out: Vec<int> = Vec::new();
    if n == 0 {
        return out;
    }
    let avail = pos(total - pos(gap) * (n - 1));
    let sum = 0;
    let i = 0;
    while i < n {
        let nat = 0;
        if i < naturals.len() {
            nat = naturals[i];
        }
        let b = base_of(cs[i], avail, nat);
        out.push(b);
        sum = sum + b;
        i++;
    }
    if sum > avail {
        return share(avail, out);
    }
    let rest = avail - sum;
    let extra: Vec<int> = Vec::new();
    let open: Vec<bool> = Vec::new();
    for c in cs {
        extra.push(0);
        open.push(weight_of(c) > 0);
    }
    // Share `rest` among the open children; a max child whose share
    // passes its cap is pinned at the cap and the rest shared again.
    let settled = false;
    while !settled {
        let ws: Vec<int> = Vec::new();
        let k = 0;
        while k < n {
            if open[k] {
                ws.push(weight_of(cs[k]));
            } else {
                ws.push(0);
            }
            k++;
        }
        let parts = share(rest, ws);
        settled = true;
        k = 0;
        while k < n {
            let cap = cap_of(cs[k]);
            if open[k] && cap >= 0 && parts[k] > cap {
                extra[k] = cap;
                rest = rest - cap;
                open[k] = false;
                settled = false;
            }
            k++;
        }
        if settled {
            k = 0;
            while k < n {
                if open[k] {
                    extra[k] = parts[k];
                }
                k++;
            }
        }
    }
    i = 0;
    while i < n {
        out[i] = out[i] + extra[i];
        i++;
    }
    return out;
}

/// Rects for children laid out left to right (`horizontal`) or top to
/// bottom inside `area`, sized by `sizes` along the main axis, `gap`
/// cells apart. On the cross axis each child takes `cross[i]` cells
/// aligned by `align` (`Stretch` ignores `cross`).
///
/// # Examples
///
/// ```
/// use tui::layout::stack_rects;
/// use tui::geom::{Align, rect};
/// # use tests::assert;
/// let none: Vec<int> = Vec::new();
/// let rs = stack_rects(rect(0, 0, 20, 4), true, [5, 15], 0, none, Align::Stretch);
/// assert!(rs[0].eq(rect(0, 0, 5, 4)));
/// assert!(rs[1].eq(rect(5, 0, 15, 4)));
/// ```
fn stack_rects(
    Rect area,
    bool horizontal,
    Vec<int> sizes,
    int gap,
    Vec<int> cross,
    Align align,
) -> Vec<Rect> {
    let out: Vec<Rect> = Vec::new();
    let at = 0;
    let i = 0;
    while i < sizes.len() {
        let want = 0;
        if i < cross.len() {
            want = cross[i];
        }
        if horizontal {
            let slot = rect(area.x + at, area.y, sizes[i], area.h);
            out.push(slot.place(sizes[i], want, Align::Stretch, align));
        } else {
            let slot = rect(area.x, area.y + at, area.w, sizes[i]);
            out.push(slot.place(want, sizes[i], align, Align::Stretch));
        }
        at = at + sizes[i] + gap;
        i++;
    }
    return out;
}

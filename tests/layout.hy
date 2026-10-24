use tests::assert;
use tui::layout::Constraint;
use tui::layout::split;
use tui::layout::stack_rects;
use tui::geom::Rect;
use tui::geom::Align;
use tui::geom::rect;

fn cs(Constraint... xs) -> Vec<Constraint> {
    let out: Vec<Constraint> = Vec::new();
    for x in xs {
        out.push(x);
    }
    return out;
}

fn ints(int... xs) -> Vec<int> {
    let out: Vec<int> = Vec::new();
    for x in xs {
        out.push(x);
    }
    return out;
}

fn same(Vec<int> a, Vec<int> b) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let i = 0;
    while i < a.len() {
        if a[i] != b[i] {
            return false;
        }
        i++;
    }
    return true;
}

fn none() -> Vec<int> {
    return Vec::new();
}

test("fixed and fill") {
    let s = split(20, cs(Constraint::Fixed(5), Constraint::Fill(1)), none(), 0);
    assert!(same(s, ints(5, 15)));
    let g = split(20, cs(Constraint::Fixed(5), Constraint::Fill(1)), none(), 2);
    assert!(same(g, ints(5, 13)));
}

test("fill weights and remainders go to the first fills") {
    let s = split(10, cs(Constraint::Fill(1), Constraint::Fill(1), Constraint::Fill(1)), none(), 0);
    assert!(same(s, ints(4, 3, 3)));
    let w = split(12, cs(Constraint::Fill(1), Constraint::Fill(2)), none(), 0);
    assert!(same(w, ints(4, 8)));
    let z = split(10, cs(Constraint::Fill(0), Constraint::Fill(1)), none(), 0);
    assert!(same(z, ints(0, 10)));
}

test("percent and auto") {
    let s = split(
        40,
        cs(Constraint::Percent(25), Constraint::Auto, Constraint::Fill(1)),
        ints(0, 7, 0),
        0,
    );
    assert!(same(s, ints(10, 7, 23)));
}

test("rigid sizes shrink in proportion when they do not fit") {
    let s = split(
        10,
        cs(Constraint::Fixed(10), Constraint::Fixed(10), Constraint::Fill(1)),
        none(),
        0,
    );
    assert!(same(s, ints(5, 5, 0)));
    let t = split(3, cs(Constraint::Fixed(4), Constraint::Fixed(2)), none(), 0);
    assert!(same(t, ints(2, 1)));
}

test("min and max") {
    let s = split(20, cs(Constraint::Min(8), Constraint::Fill(1)), none(), 0);
    assert!(same(s, ints(14, 6)));
    let m = split(20, cs(Constraint::Max(4), Constraint::Fill(1)), none(), 0);
    assert!(same(m, ints(4, 16)));
    let only = split(20, cs(Constraint::Max(4), Constraint::Max(5)), none(), 0);
    assert!(same(only, ints(4, 5)));
}

test("leftover without fills stays unused; empty input") {
    let s = split(20, cs(Constraint::Fixed(3), Constraint::Auto), ints(0, 4), 1);
    assert!(same(s, ints(3, 4)));
    assert!(split(10, cs(), none(), 1).len() == 0);
    let tight = split(2, cs(Constraint::Fill(1), Constraint::Fill(1)), none(), 5);
    assert!(same(tight, ints(0, 0)));
}

test("stack rects") {
    let area = rect(1, 2, 20, 4);
    let rs = stack_rects(area, true, ints(5, 10), 1, ints(1, 9), Align::Stretch);
    assert!(rs[0].eq(rect(1, 2, 5, 4)));
    assert!(rs[1].eq(rect(7, 2, 10, 4)));
    let cs2 = stack_rects(area, false, ints(1, 2), 0, ints(6, 30), Align::Center);
    assert!(cs2[0].eq(rect(8, 2, 6, 1)));
    assert!(cs2[1].eq(rect(1, 3, 20, 2)));
}
